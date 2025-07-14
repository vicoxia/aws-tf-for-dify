locals {
  rds_subnets = length(var.rds_subnets) > 0 ? var.rds_subnets : (local.create_vpc ? aws_subnet.private[*].id : [])
  
  # Environment-specific RDS configurations
  rds_config = var.environment == "test" ? {
    instance_class    = "db.t4g.medium"  # 2 vCPU, 4 GB RAM (Graviton)
    allocated_storage = 256
    max_allocated_storage = 512
  } : {
    instance_class    = "db.t4g.large"   # 2 vCPU, 8 GB RAM (Graviton)
    allocated_storage = 512
    max_allocated_storage = 1024
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "dify-${var.environment}-db-subnet-group"
  subnet_ids = local.rds_subnets

  tags = {
    Name        = "dify-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# RDS Security Group
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

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "dify-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "14.9"
  instance_class = local.rds_config.instance_class

  allocated_storage     = local.rds_config.allocated_storage
  max_allocated_storage = local.rds_config.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "dify"
  username = "dify_admin"
  password = random_password.rds_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  publicly_accessible = var.rds_public_accessible
  skip_final_snapshot = true

  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  tags = {
    Name        = "dify-${var.environment}-postgres"
    Environment = var.environment
  }
}

resource "random_password" "rds_password" {
  length  = 16
  special = true
}

# Store RDS password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "rds_password" {
  name = "dify-${var.environment}-rds-password"

  tags = {
    Name        = "dify-${var.environment}-rds-password"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.rds_password.result
    endpoint = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}