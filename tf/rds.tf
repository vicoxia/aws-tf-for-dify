locals {
  rds_subnets = length(var.rds_subnets) > 0 ? var.rds_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
}

# RDS Subnet Group (可以用于Aurora)
resource "aws_db_subnet_group" "main" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = local.rds_subnets

  tags = {
    Name        = "${var.cluster_name}-db-subnet-group"
    Environment = var.environment
  }
}

# RDS Security Group (可以用于Aurora)
resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
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
    Name        = "${var.cluster_name}-rds-sg"
    Environment = var.environment
  }
}

# Aurora Serverless v2 Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier      = "${var.cluster_name}-aurora-postgres"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"  # 对于Serverless v2，使用provisioned模式
  engine_version          = var.db_engine_version
  database_name           = "dify"
  master_username         = "postgres"
  master_password         = "DifyRdsPassword123!"  # 请修改为您的密码
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  
  skip_final_snapshot     = true
  backup_retention_period = var.db_backup_retention_period
  preferred_backup_window = var.db_backup_window
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  
  # 启用存储加密
  storage_encrypted       = true
  
  # 启用Serverless v2
  serverlessv2_scaling_configuration {
    min_capacity = var.db_min_capacity
    max_capacity = var.db_max_capacity
  }
  
  tags = {
    Name        = "${var.cluster_name}-aurora-postgres"
    Environment = var.environment
  }
}

# Aurora Serverless v2 不需要单独的实例资源
# 容量由 serverlessv2_scaling_configuration 自动管理

# ──────────────── Database Initialization ────────────────
# Note: Database creation is now handled by the Dify Helm Chart
# The chart includes initdb scripts that create the required databases:
# - enterprise (for enterprise features)
# - audit (for audit logging)
# - dify_plugin_daemon (for plugin system)
#
# This is configured in the values.yaml file under:
# - postgresql.primary.initdb.scripts (for internal PostgreSQL)
# - Database migration jobs (for external PostgreSQL like Aurora)
#
# No additional null_resource is needed as the Helm chart handles
# database initialization automatically during deployment.

# 输出Aurora集群端点
output "aurora_cluster_endpoint" {
  description = "Aurora集群端点"
  value       = aws_rds_cluster.main.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora读取器端点"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "additional_databases_info" {
  description = "Additional databases information"
  value = {
    plugin_daemon = {
      database_name = "dify_plugin_daemon"
      host         = aws_rds_cluster.main.endpoint
      port         = 5432
      username     = "postgres"
    }
    enterprise = {
      database_name = "dify_enterprise"
      host         = aws_rds_cluster.main.endpoint
      port         = 5432
      username     = "postgres"
    }
    audit = {
      database_name = "dify_audit"
      host         = aws_rds_cluster.main.endpoint
      port         = 5432
      username     = "postgres"
    }
  }
}
