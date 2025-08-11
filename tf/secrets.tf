# ──────────────── AWS Secrets Manager ────────────────
# 用于安全存储和管理敏感信息

# RDS主密码
resource "aws_secretsmanager_secret" "rds_password" {
  name        = "dify-${var.environment}-rds-password"
  description = "RDS master password for Dify ${var.environment} environment"
  
  tags = {
    Name        = "dify-${var.environment}-rds-password"
    Environment = var.environment
    Service     = "dify"
    Type        = "database"
  }
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    username = var.rds_username
    password = var.rds_password
    engine   = "postgres"
    host     = aws_rds_cluster.main.endpoint
    port     = 5432
    dbname   = aws_rds_cluster.main.database_name
  })
}

# OpenSearch密码
resource "aws_secretsmanager_secret" "opensearch_password" {
  name        = "dify-${var.environment}-opensearch-password"
  description = "OpenSearch admin password for Dify ${var.environment} environment"
  
  tags = {
    Name        = "dify-${var.environment}-opensearch-password"
    Environment = var.environment
    Service     = "dify"
    Type        = "search"
  }
}

resource "aws_secretsmanager_secret_version" "opensearch_password" {
  secret_id = aws_secretsmanager_secret.opensearch_password.id
  secret_string = jsonencode({
    username = var.opensearch_admin_name
    password = var.opensearch_password
    endpoint = aws_opensearch_domain.main.endpoint
  })
}

# Dify应用密钥
resource "aws_secretsmanager_secret" "dify_secrets" {
  name        = "dify-${var.environment}-app-secrets"
  description = "Dify application secrets for ${var.environment} environment"
  
  tags = {
    Name        = "dify-${var.environment}-app-secrets"
    Environment = var.environment
    Service     = "dify"
    Type        = "application"
  }
}

resource "aws_secretsmanager_secret_version" "dify_secrets" {
  secret_id = aws_secretsmanager_secret.dify_secrets.id
  secret_string = jsonencode({
    app_secret_key                = var.dify_app_secret_key
    admin_api_secret_key_salt     = var.dify_admin_api_secret_key_salt
    sandbox_api_key               = var.dify_sandbox_api_key
    inner_api_key                 = var.dify_inner_api_key
    plugin_api_key                = var.dify_plugin_api_key
    plugin_inner_api_key          = var.dify_plugin_inner_api_key
  })
}

# ──────────────── IAM权限 ────────────────
# 允许EKS服务账户访问Secrets Manager

resource "aws_iam_policy" "secrets_manager_access" {
  name        = "dify-${var.environment}-secrets-manager-access"
  description = "Allow access to Dify secrets in Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.rds_password.arn,
          aws_secretsmanager_secret.opensearch_password.arn,
          aws_secretsmanager_secret.dify_secrets.arn
        ]
      }
    ]
  })

  tags = {
    Name        = "dify-${var.environment}-secrets-manager-policy"
    Environment = var.environment
  }
}

# 将策略附加到现有的IAM角色
resource "aws_iam_role_policy_attachment" "dify_api_secrets_access" {
  role       = aws_iam_role.dify_ee_s3_role.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}

# ──────────────── 输出信息 ────────────────

output "secrets_manager_info" {
  description = "Secrets Manager information for password retrieval"
  value = {
    rds_secret_name        = aws_secretsmanager_secret.rds_password.name
    opensearch_secret_name = aws_secretsmanager_secret.opensearch_password.name
    dify_secrets_name      = aws_secretsmanager_secret.dify_secrets.name
    region                 = var.aws_region
  }
}

# 敏感输出（仅在需要时显示）
output "password_retrieval_commands" {
  description = "Commands to retrieve passwords from Secrets Manager"
  value = {
    rds_password = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.rds_password.name} --region ${var.aws_region} --query SecretString --output text | jq -r '.password'"
    opensearch_password = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.opensearch_password.name} --region ${var.aws_region} --query SecretString --output text | jq -r '.password'"
    all_dify_secrets = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.dify_secrets.name} --region ${var.aws_region} --query SecretString --output text | jq ."
  }
  sensitive = true
}