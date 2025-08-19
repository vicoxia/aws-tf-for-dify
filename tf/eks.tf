locals {
  cluster_subnets = length(var.eks_cluster_subnets) > 0 ? var.eks_cluster_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
  node_subnets    = length(var.eks_nodes_subnets) > 0 ? var.eks_nodes_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])

  # IAM策略ARN配置
  iam_policy_arns = {
    eks_cluster_policy            = "${local.arn_prefix}:iam::aws:policy/AmazonEKSClusterPolicy"
    eks_worker_node_policy        = "${local.arn_prefix}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    eks_cni_policy               = "${local.arn_prefix}:iam::aws:policy/AmazonEKS_CNI_Policy"
    eks_container_registry_policy = "${local.arn_prefix}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  # 环境特定的节点配置，随架构切换
  node_config = var.environment == "test" ? (
    var.eks_arch == "amd64" ? {
      instance_types = ["m7a.xlarge"]
      desired_size   = 1
      max_size       = 2
      min_size       = 1
      } : {
      instance_types = ["m7g.xlarge"]
      desired_size   = 1
      max_size       = 2
      min_size       = 1
    }
    ) : (
    var.eks_arch == "amd64" ? {
      instance_types = ["m7a.2xlarge"]
      desired_size   = 6
      max_size       = 10
      min_size       = 6
      } : {
      instance_types = ["m7g.2xlarge"]
      desired_size   = 6
      max_size       = 10
      min_size       = 6
    }
  )
}

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

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
  policy_arn = local.iam_policy_arns.eks_cluster_policy
  role       = aws_iam_role.eks_cluster.name
}

# EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_group" {
  name = "${var.cluster_name}-node-group-role"

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
  policy_arn = local.iam_policy_arns.eks_worker_node_policy
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = local.iam_policy_arns.eks_cni_policy
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = local.iam_policy_arns.eks_container_registry_policy
  role       = aws_iam_role.eks_node_group.name
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = local.cluster_subnets
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }
}

# EKS Nodes Security Group
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.cluster_name}-nodes-"
  vpc_id      = local.vpc_id

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-nodes-sg"
    Environment = var.environment
  }
}

# Launch Template for EKS Nodes
# Used to explicitly specify the node security group, ensuring that our custom security group is used instead of the cluster's default security group
resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.cluster_name}-nodes-"

  vpc_security_group_ids = [
    aws_security_group.eks_nodes.id,
    aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  ]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.prefix}-${var.environment}-${var.cluster_name}-node"
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.cluster_name}-nodes-launch-template"
    Environment = var.environment
  }
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = local.node_subnets

  scaling_config {
    desired_size = local.node_config.desired_size
    max_size     = local.node_config.max_size
    min_size     = local.node_config.min_size
  }

  instance_types = local.node_config.instance_types
  ami_type       = var.eks_arch == "amd64" ? "AL2023_x86_64_STANDARD" : "AL2023_ARM_64_STANDARD"

  # Use launch template to specify node security group
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name        = "${var.prefix}-${var.environment}-${var.cluster_name}-nodes"
    Environment = var.environment
  }
}

