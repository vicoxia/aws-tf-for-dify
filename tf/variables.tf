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

# RDS和OpenSearch密码现在直接在相应的.tf文件中硬编码
# 不再需要这些变量，密码直接在rds.tf和opensearch.tf中设置

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

# ──────────────── Helm Chart Configuration ────────────────

variable "dify_namespace" {
  description = "Kubernetes namespace for Dify application"
  type        = string
  default     = "dify"
}

# AWS Load Balancer Controller
variable "install_aws_load_balancer_controller" {
  description = "Install AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_version" {
  description = "AWS Load Balancer Controller Helm chart version"
  type        = string
  default     = "1.6.2"
}

# NGINX Ingress Controller
variable "install_nginx_ingress" {
  description = "Install NGINX Ingress Controller (alternative to ALB)"
  type        = bool
  default     = false
}

variable "nginx_ingress_version" {
  description = "NGINX Ingress Controller Helm chart version"
  type        = string
  default     = "4.8.3"
}

# Cert-Manager
variable "install_cert_manager" {
  description = "Install Cert-Manager for SSL certificates"
  type        = bool
  default     = true
}

variable "cert_manager_version" {
  description = "Cert-Manager Helm chart version"
  type        = string
  default     = "v1.13.2"
}

# ──────────────── Infrastructure Configuration ────────────────

# Cluster Configuration
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "dify-eks-cluster"
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.28"
}

# Node Group Configuration
variable "node_group_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 4
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

# VPC Configuration
variable "use_existing_vpc" {
  description = "Whether to use an existing VPC"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for VPC"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (for existing VPC)"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (for existing VPC)"
  type        = list(string)
  default     = []
}

# Database Configuration (Aurora Serverless v2)
variable "db_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "17.5"
}

variable "db_min_capacity" {
  description = "Aurora Serverless v2 minimum capacity (ACU)"
  type        = number
  default     = 0.5
}

variable "db_max_capacity" {
  description = "Aurora Serverless v2 maximum capacity (ACU)"
  type        = number
  default     = 4
}

variable "db_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

variable "db_backup_window" {
  description = "RDS backup window"
  type        = string
  default     = "03:00-04:00"
}

# Redis Configuration (Cluster Mode Disabled)
# 节点数量和高可用性配置根据环境自动设置：
# - test环境：单节点模式 (cache.t4g.micro)
# - prod环境：主从复制模式 (用户配置的实例类型)
variable "redis_node_type" {
  description = "ElastiCache Redis node type (仅用于生产环境，测试环境固定使用cache.t4g.micro)"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_parameter_group_name" {
  description = "Redis parameter group name"
  type        = string
  default     = "default.redis7"
}

variable "redis_engine_version" {
  description = "ElastiCache Redis engine version"
  type        = string
  default     = "7.1"
}

# OpenSearch Configuration
variable "opensearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
  default     = 1
}

variable "opensearch_ebs_volume_size" {
  description = "OpenSearch EBS volume size in GB"
  type        = number
  default     = 20
}

variable "opensearch_engine_version" {
  description = "OpenSearch engine version"
  type        = string
  default     = "OpenSearch_2.19"
}

# Storage Configuration
variable "s3_bucket_name" {
  description = "S3 bucket name (will have random suffix added)"
  type        = string
  default     = "dify-storage"
}

variable "s3_versioning_enabled" {
  description = "Enable S3 versioning"
  type        = bool
  default     = true
}

# ECR Configuration
variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "dify"
}

variable "ecr_image_tag_mutability" {
  description = "ECR image tag mutability"
  type        = string
  default     = "MUTABLE"
}