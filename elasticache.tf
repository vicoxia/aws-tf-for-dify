locals {
  redis_subnets = length(var.redis_subnets) > 0 ? var.redis_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
  
  # Environment-specific Redis configurations
  redis_config = var.environment == "test" ? {
    node_type = "cache.t4g.micro"  # 1 GB RAM (Graviton)
    num_cache_nodes = 1
  } : {
    node_type = "cache.t4g.small"  # 2 GB RAM (Graviton)
    num_cache_nodes = 1
  }
}

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "dify-${var.environment}-redis-subnet-group"
  subnet_ids = local.redis_subnets

  tags = {
    Name        = "dify-${var.environment}-redis-subnet-group"
    Environment = var.environment
  }
}

# ElastiCache Security Group
resource "aws_security_group" "redis" {
  name_prefix = "dify-${var.environment}-redis-"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
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
    Name        = "dify-${var.environment}-redis-sg"
    Environment = var.environment
  }
}

# ElastiCache Redis Cluster
resource "aws_elasticache_cluster" "main" {
  cluster_id           = "dify-${var.environment}-redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = local.redis_config.node_type
  num_cache_nodes      = local.redis_config.num_cache_nodes
  parameter_group_name = "default.redis7.x"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  tags = {
    Name        = "dify-${var.environment}-redis"
    Environment = var.environment
  }
}