locals {
  opensearch_subnets = length(var.opensearch_subnets) > 0 ? var.opensearch_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
  
  # Environment-specific OpenSearch configurations
  opensearch_config = var.environment == "test" ? {
    instance_type  = "m6g.large.search"  # 4 vCPU, 8 GB RAM (Graviton)
    instance_count = 1
    ebs_volume_size = 100
  } : {
    instance_type  = "m6g.4xlarge.search"  # 16 vCPU, 64 GB RAM (Graviton)
    instance_count = 3
    ebs_volume_size = 100
  }
}

# OpenSearch Security Group
resource "aws_security_group" "opensearch" {
  name_prefix = "dify-${var.environment}-opensearch-"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  ingress {
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "dify-${var.environment}-opensearch-sg"
    Environment = var.environment
  }
}

# OpenSearch Domain
resource "aws_opensearch_domain" "main" {
  domain_name    = "dify-${var.environment}-opensearch"
  engine_version = "OpenSearch_2.19"

  cluster_config {
    instance_type  = local.opensearch_config.instance_type
    instance_count = local.opensearch_config.instance_count
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = local.opensearch_config.ebs_volume_size
  }

  vpc_options {
    subnet_ids         = slice(local.opensearch_subnets, 0, min(length(local.opensearch_subnets), local.opensearch_config.instance_count))
    security_group_ids = [aws_security_group.opensearch.id]
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.opensearch_admin_name
      master_user_password = var.opensearch_password
    }
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "es:*"
        Resource = "arn:aws:es:${var.aws_region}:${var.aws_account_id}:domain/dify-${var.environment}-opensearch/*"
      }
    ]
  })

  tags = {
    Name        = "dify-${var.environment}-opensearch"
    Environment = var.environment
  }
}
