locals {
  rds_subnets = length(var.rds_subnets) > 0 ? var.rds_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
}

# RDS Subnet Group (可以用于Aurora)
# RDS凭证存储（Secrets Manager）
resource "aws_secretsmanager_secret" "rds_credentials" {
  name        = "${var.prefix}-${var.environment}-${var.cluster_name}-rds-credentials"
  description = "RDS Aurora cluster credentials for Dify"

  tags = {
    Name        = "${var.prefix}-${var.environment}-${var.cluster_name}-rds-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = "postgres"
    password = var.db_master_password
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.prefix}-${var.environment}-${var.cluster_name}-db-subnet-group"
  subnet_ids = local.rds_subnets

  tags = {
    Name        = "${var.prefix}-${var.environment}-${var.cluster_name}-db-subnet-group"
    Environment = var.environment
  }
}

# RDS Security Group (可以用于Aurora)
resource "aws_security_group" "rds" {
  name_prefix = "${var.prefix}-${var.environment}-${var.cluster_name}-rds-"
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
    Name        = "${var.prefix}-${var.environment}-${var.cluster_name}-rds-sg"
    Environment = var.environment
  }
}

# Aurora Serverless v2 Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier     = "${var.cluster_name}-aurora-postgres"
  engine                 = "aurora-postgresql"
  engine_mode            = "provisioned" # 对于Serverless v2，使用provisioned模式
  engine_version         = var.db_engine_version
  database_name          = "dify"
  master_username        = "postgres"
  master_password        = var.db_master_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot          = true
  backup_retention_period      = var.db_backup_retention_period
  preferred_backup_window      = var.db_backup_window
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # 启用存储加密
  storage_encrypted = true

  # 启用Data API以支持无网络连接的数据库操作
  enable_http_endpoint = true

  # 启用Serverless v2
  serverlessv2_scaling_configuration {
    min_capacity = var.db_min_capacity
    max_capacity = var.db_max_capacity
  }

  tags = {
    Name        = "${var.prefix}-${var.environment}-${var.cluster_name}-aurora-postgres"
    Environment = var.environment
  }
}

# Aurora Serverless v2 实例
# 注意：Serverless v2 仍需要创建实例，但实例类型必须是 "db.serverless"
resource "aws_rds_cluster_instance" "main" {
  count              = var.environment == "test" ? 1 : 2 # 测试环境1个，生产环境2个
  identifier         = "${var.cluster_name}-aurora-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless" # Serverless v2 必须使用此实例类型
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  performance_insights_enabled = var.environment == "prod" ? true : false

  tags = {
    Name        = "${var.prefix}-${var.environment}-${var.cluster_name}-aurora-instance-${count.index + 1}"
    Environment = var.environment
  }
}

# ──────────────── Database Initialization ────────────────
# Create additional databases required by Dify Enterprise
# These databases must be created at the Aurora cluster level
# as Helm charts cannot create databases on external PostgreSQL instances

# Database creation is handled by the null_resource below using RDS Data API

# Use local-exec to create the additional databases via RDS Data API
resource "null_resource" "create_additional_databases" {
  depends_on = [aws_rds_cluster_instance.main, aws_secretsmanager_secret_version.rds_credentials]

  provisioner "local-exec" {
    command = "bash ${path.module}/create_dify_databases_dataapi.sh"

    environment = {
      CLUSTER_ARN = aws_rds_cluster.main.arn
      SECRET_ARN  = aws_secretsmanager_secret.rds_credentials.arn
      AWS_REGION  = var.aws_region
    }
  }

  # Trigger recreation if cluster or secret changes
  triggers = {
    cluster_arn = aws_rds_cluster.main.arn
    secret_arn  = aws_secretsmanager_secret.rds_credentials.arn
    script_hash = filemd5("${path.module}/create_dify_databases_dataapi.sh")
  }
}



# 输出Aurora集群端点
output "aurora_cluster_endpoint" {
  description = "Aurora集群端点"
  value       = aws_rds_cluster.main.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora读取器端点"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "aurora_instance_count" {
  description = "Aurora实例数量"
  value       = length(aws_rds_cluster_instance.main)
}

output "aurora_instance_ids" {
  description = "Aurora实例ID列表"
  value       = aws_rds_cluster_instance.main[*].id
}

output "rds_credentials_secret_arn" {
  description = "RDS凭证Secrets Manager ARN"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "rds_cluster_arn" {
  description = "Aurora集群ARN（用于Data API）"
  value       = aws_rds_cluster.main.arn
}

output "additional_databases_info" {
  description = "Additional databases information"
  value = {
    plugin_daemon = {
      database_name = "dify_plugin_daemon"
      host          = aws_rds_cluster.main.endpoint
      port          = 5432
      username      = "postgres"
    }
    enterprise = {
      database_name = "dify_enterprise"
      host          = aws_rds_cluster.main.endpoint
      port          = 5432
      username      = "postgres"
    }
    audit = {
      database_name = "dify_audit"
      host          = aws_rds_cluster.main.endpoint
      port          = 5432
      username      = "postgres"
    }
  }
}
