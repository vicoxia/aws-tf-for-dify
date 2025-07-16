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
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.main.cache_nodes[0].port
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
