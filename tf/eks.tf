locals {
  cluster_subnets = length(var.eks_cluster_subnets) > 0 ? var.eks_cluster_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
  node_subnets    = length(var.eks_nodes_subnets) > 0 ? var.eks_nodes_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
  
  # 环境特定的节点配置 (使用最新Graviton3处理器)
  node_config = var.environment == "test" ? {
    instance_types  = ["m7g.xlarge"]    # 4 vCPU, 16 GB RAM (Graviton3)
    desired_size    = 1                 # 1个工作节点
    max_size        = 2                 # 最大2个节点
    min_size        = 1                 # 最小1个节点
  } : {
    instance_types  = ["m7g.2xlarge"]   # 8 vCPU, 32 GB RAM (Graviton3)
    desired_size    = 6                 # 6个工作节点
    max_size        = 10                # 最大10个节点
    min_size        = 6                 # 最小6个节点
  }
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
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
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
  ami_type       = "AL2_ARM_64"  # 使用Amazon Linux 2 ARM64 (Graviton) - 兼容EKS 1.33

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name        = "${var.cluster_name}-nodes"
    Environment = var.environment
  }
}

