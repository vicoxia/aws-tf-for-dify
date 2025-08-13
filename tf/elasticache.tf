locals {
  redis_subnets = length(var.redis_subnets) > 0 ? var.redis_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
  
  # 环境特定的Redis配置
  redis_config = var.environment == "test" ? {
    num_cache_clusters         = 1      # 单节点模式
    automatic_failover_enabled = false  # 禁用自动故障转移
    multi_az_enabled          = false  # 禁用Multi-AZ
    node_type                 = "cache.t4g.micro"  # 小实例类型
  } : {
    num_cache_clusters         = 2      # 主从复制模式
    automatic_failover_enabled = true   # 启用自动故障转移
    multi_az_enabled          = true   # 启用Multi-AZ
    node_type                 = var.redis_node_type  # 使用配置的实例类型
  }
}

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.prefix}-${var.environment}-${var.cluster_name}-redis-subnet-group"
  subnet_ids = local.redis_subnets

  tags = {
    Name        = "${var.prefix}-${var.environment}-${var.cluster_name}-redis-subnet-group"
    Environment = var.environment
  }
}

# ElastiCache Security Group
resource "aws_security_group" "redis" {
  name_prefix = "${var.prefix}-${var.environment}-${var.cluster_name}-redis-"
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
    Name        = "${var.prefix}-${var.environment}-${var.cluster_name}-redis-sg"
    Environment = var.environment
  }
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.prefix}-${var.environment}-${var.cluster_name}-redis-params"
  family = "redis7"  # Redis 7.x的有效参数组族
}

# ElastiCache Redis Replication Group (Cluster Mode Disabled)
# 根据环境自动配置：test=单节点，prod=主从复制
resource "aws_elasticache_replication_group" "main" {
  replication_group_id         = "${var.cluster_name}-redis"
  description                  = "Redis ${var.environment} environment for ${var.cluster_name}"
  
  engine                       = "redis"
  engine_version              = var.redis_engine_version
  node_type                   = local.redis_config.node_type
  port                        = 6379
  parameter_group_name        = var.redis_parameter_group_name
  
  # 根据环境配置节点数量
  num_cache_clusters          = local.redis_config.num_cache_clusters
  
  # 明确禁用cluster mode
  num_node_groups             = null
  replicas_per_node_group     = null
  
  subnet_group_name           = aws_elasticache_subnet_group.main.name
  security_group_ids          = [aws_security_group.redis.id]
  
  # 根据环境配置高可用性功能
  automatic_failover_enabled  = local.redis_config.automatic_failover_enabled
  multi_az_enabled           = local.redis_config.multi_az_enabled
  
  # 备份配置
  snapshot_retention_limit    = var.environment == "test" ? 0 : 3
  snapshot_window            = "03:00-05:00"
  maintenance_window         = "sun:05:00-sun:07:00"
  
  tags = {
    Name        = "${var.prefix}-${var.environment}-${var.cluster_name}-redis"
    Environment = var.environment
    Mode        = var.environment == "test" ? "single-node" : "primary-replica"
  }
}
