output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.dify.repository_url
}

output "ecr_ee_plugin_repository_url" {
  description = "ECR EE Plugin repository URL"
  value       = aws_ecr_repository.dify_ee_plugin.repository_url
}

output "ecr_ee_plugin_repository_name" {
  description = "ECR EE Plugin repository name"
  value       = aws_ecr_repository.dify_ee_plugin.name
}

output "s3_bucket_name" {
  description = "S3 bucket name for storage"
  value       = aws_s3_bucket.dify_storage.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.dify_storage.arn
}

output "s3_iam_role_arn" {
  description = "IAM role ARN for S3 access (IRSA)"
  value       = aws_iam_role.s3_access.arn
}

# ──────────────── Dify EE IRSA Role ARNs ────────────────
output "dify_ee_s3_role_arn" {
  description = "Dify EE S3-only IAM role ARN"
  value       = aws_iam_role.dify_ee_s3_role.arn
}

output "dify_ee_s3_ecr_role_arn" {
  description = "Dify EE S3+ECR IAM role ARN"
  value       = aws_iam_role.dify_ee_s3_ecr_role.arn
}

output "dify_ee_ecr_pull_role_arn" {
  description = "Dify EE ECR image pull IAM role ARN"
  value       = aws_iam_role.dify_ee_ecr_pull_role.arn
}

# ──────────────── Service Account Information ────────────────
output "dify_ee_service_accounts_info" {
  description = "Information about created Dify EE ServiceAccounts"
  value = {
    dify_api = {
      name      = kubernetes_service_account.dify_api.metadata[0].name
      namespace = kubernetes_service_account.dify_api.metadata[0].namespace
      role_arn  = aws_iam_role.dify_ee_s3_role.arn
    }
    dify_plugin_crd = {
      name      = kubernetes_service_account.dify_plugin_crd.metadata[0].name
      namespace = kubernetes_service_account.dify_plugin_crd.metadata[0].namespace
      role_arn  = aws_iam_role.dify_ee_s3_ecr_role.arn
    }
    dify_plugin_runner = {
      name      = kubernetes_service_account.dify_plugin_runner.metadata[0].name
      namespace = kubernetes_service_account.dify_plugin_runner.metadata[0].namespace
      role_arn  = aws_iam_role.dify_ee_ecr_pull_role.arn
    }
    dify_plugin_connector = {
      name      = kubernetes_service_account.dify_plugin_connector.metadata[0].name
      namespace = kubernetes_service_account.dify_plugin_connector.metadata[0].namespace
      role_arn  = aws_iam_role.dify_ee_s3_role.arn
    }
    # Alternative names for compatibility with upgrade guide
    dify_plugin_build = {
      name      = kubernetes_service_account.dify_plugin_build.metadata[0].name
      namespace = kubernetes_service_account.dify_plugin_build.metadata[0].namespace
      role_arn  = aws_iam_role.dify_ee_s3_ecr_role.arn
    }
    dify_plugin_build_run = {
      name      = kubernetes_service_account.dify_plugin_build_run.metadata[0].name
      namespace = kubernetes_service_account.dify_plugin_build_run.metadata[0].namespace
      role_arn  = aws_iam_role.dify_ee_ecr_pull_role.arn
    }
  }
}

# ──────────────── Helm Deployment Information ────────────────

output "helm_releases_status" {
  description = "Status of deployed Helm releases"
  value = {
    aws_load_balancer_controller = var.install_aws_load_balancer_controller ? {
      name      = "aws-load-balancer-controller"
      namespace = "kube-system"
      status    = var.install_aws_load_balancer_controller ? "deployed" : "not_installed"
    } : null
    
    nginx_ingress = var.install_nginx_ingress ? {
      name      = "nginx-ingress"
      namespace = "ingress-nginx"
      status    = var.install_nginx_ingress ? "deployed" : "not_installed"
    } : null
    
    cert_manager = var.install_cert_manager ? {
      name      = "cert-manager"
      namespace = "cert-manager"
      status    = var.install_cert_manager ? "deployed" : "not_installed"
    } : null
    

    


  }
}



output "rds_endpoint" {
  description = "Aurora PostgreSQL endpoint"
  value       = aws_rds_cluster.main.endpoint
  sensitive   = true
}

output "rds_reader_endpoint" {
  description = "Aurora PostgreSQL reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "Aurora PostgreSQL port"
  value       = aws_rds_cluster.main.port
}

output "rds_database_name" {
  description = "Aurora PostgreSQL database name"
  value       = aws_rds_cluster.main.database_name
}

output "rds_username" {
  description = "Aurora PostgreSQL username"
  value       = aws_rds_cluster.main.master_username
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.main.port
}

output "opensearch_endpoint" {
  description = "OpenSearch endpoint"
  value       = aws_opensearch_domain.main.endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch dashboard endpoint"
  value       = aws_opensearch_domain.main.dashboard_endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = local.create_vpc ? aws_subnet.private[*].id : []
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = local.create_vpc ? aws_subnet.public[*].id : []
}
