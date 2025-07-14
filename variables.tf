variable "environment" {
  description = "Deployment environment (test or prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.environment)
    error_message = "Environment must be either 'test' or 'prod'."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC ID (optional)"
  type        = string
  default     = ""
}

variable "eks_cluster_subnets" {
  description = "Subnet IDs for EKS control plane"
  type        = list(string)
  default     = []
}

variable "eks_nodes_subnets" {
  description = "Subnet IDs for EKS worker nodes"
  type        = list(string)
  default     = []
}

variable "redis_subnets" {
  description = "Subnet IDs for Redis"
  type        = list(string)
  default     = []
}

variable "rds_subnets" {
  description = "Subnet IDs for RDS"
  type        = list(string)
  default     = []
}

variable "opensearch_subnets" {
  description = "Subnet IDs for OpenSearch"
  type        = list(string)
  default     = []
}

variable "opensearch_admin_name" {
  description = "OpenSearch master username"
  type        = string
  default     = "admin"
}

variable "opensearch_password" {
  description = "OpenSearch master password"
  type        = string
  sensitive   = true
}

variable "rds_public_accessible" {
  description = "Make RDS publicly accessible"
  type        = bool
  default     = false
}

variable "aws_eks_chart_repo_url" {
  description = "AWS EKS Helm chart repository URL (for China regions)"
  type        = string
  default     = ""
}