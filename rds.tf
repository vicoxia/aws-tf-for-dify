locals {
  rds_subnets = length(var.rds_subnets) > 0 ? var.rds_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
  
  # Environment-specific Aurora Serverless configurations
  aurora_config = var.environment == "test" ? {
    min_capacity = 0.5  # 最小容量（ACU）
    max_capacity = 4    # 最大容量（ACU）
  } : {
    min_capacity = 1    # 最小容量（ACU）
    max_capacity = 8    # 最大容量（ACU）
  }
}

# RDS Subnet Group (可以用于Aurora)
resource "aws_db_subnet_group" "main" {
  name       = "dify-${var.environment}-db-subnet-group"
  subnet_ids = local.rds_subnets

  tags = {
    Name        = "dify-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# RDS Security Group (可以用于Aurora)
resource "aws_security_group" "rds" {
  name_prefix = "dify-${var.environment}-rds-"
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
    Name        = "dify-${var.environment}-rds-sg"
    Environment = var.environment
  }
}

# Aurora Serverless v2 Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier      = "dify-${var.environment}-aurora-postgres"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"  # 对于Serverless v2，使用provisioned模式
  engine_version          = "15.5"         # 使用最新的Aurora PostgreSQL 15版本
  database_name           = "dify"
  master_username         = var.rds_username
  master_password         = var.rds_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  
  skip_final_snapshot     = true
  backup_retention_period = var.environment == "prod" ? 7 : 1
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  
  # 启用存储加密
  storage_encrypted       = true
  
  # 启用Serverless v2
  serverlessv2_scaling_configuration {
    min_capacity = local.aurora_config.min_capacity
    max_capacity = local.aurora_config.max_capacity
  }
  
  tags = {
    Name        = "dify-${var.environment}-aurora-postgres"
    Environment = var.environment
  }
}

# Aurora Serverless v2 实例
resource "aws_rds_cluster_instance" "main" {
  identifier          = "dify-${var.environment}-aurora-postgres-instance"
  cluster_identifier  = aws_rds_cluster.main.id
  instance_class      = "db.serverless"  # 使用serverless实例类型
  engine              = aws_rds_cluster.main.engine
  engine_version      = aws_rds_cluster.main.engine_version
  publicly_accessible = var.rds_public_accessible
  
  tags = {
    Name        = "dify-${var.environment}-aurora-postgres-instance"
    Environment = var.environment
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
