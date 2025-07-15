locals {
  cluster_subnets = length(var.eks_cluster_subnets) > 0 ? var.eks_cluster_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
  node_subnets    = length(var.eks_nodes_subnets) > 0 ? var.eks_nodes_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
  
  # Environment-specific configurations
  node_config = var.environment == "test" ? {
    desired_size = 1
    max_size     = 2
    min_size     = 1
    instance_types = ["m7g.xlarge"]  # 4 vCPU, 16 GB RAM (Graviton)
  } : {
    desired_size = 6
    max_size     = 8
    min_size     = 6
    instance_types = ["m7g.2xlarge"]  # 8 vCPU, 32 GB RAM (Graviton)
  }
}

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster" {
  name = "dify-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_group" {
  name = "dify-${var.environment}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# Get latest EKS version
data "aws_eks_cluster_versions" "latest" {}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "dify-${var.environment}-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = data.aws_eks_cluster_versions.latest.latest_version

  vpc_config {
    subnet_ids = local.cluster_subnets
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name        = "dify-${var.environment}-cluster"
    Environment = var.environment
  }
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "dify-${var.environment}-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = local.node_subnets
  ami_type        = "AL2_ARM_64"  # Graviton support

  scaling_config {
    desired_size = local.node_config.desired_size
    max_size     = local.node_config.max_size
    min_size     = local.node_config.min_size
  }

  instance_types = local.node_config.instance_types

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name        = "dify-${var.environment}-nodes"
    Environment = var.environment
  }
}