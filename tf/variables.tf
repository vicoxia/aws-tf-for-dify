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

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
  default     = "postgres@123!"
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

# Dify Application
variable "install_dify_chart" {
  description = "Install Dify application via Helm chart"
  type        = bool
  default     = false
}

variable "dify_helm_repo_url" {
  description = "Dify Helm chart repository URL"
  type        = string
  default     = "https://charts.dify.ai"
}

variable "dify_helm_chart_name" {
  description = "Dify Helm chart name"
  type        = string
  default     = "dify"
}

variable "dify_helm_chart_version" {
  description = "Dify Helm chart version"
  type        = string
  default     = "latest"
}

variable "dify_image_tag" {
  description = "Dify application image tag"
  type        = string
  default     = "latest"
}

variable "dify_hostname" {
  description = "Hostname for Dify application"
  type        = string
  default     = "dify.example.com"
}

variable "dify_ingress_enabled" {
  description = "Enable ingress for Dify application"
  type        = bool
  default     = true
}

variable "dify_ingress_class" {
  description = "Ingress class for Dify application"
  type        = string
  default     = "alb"
}

variable "dify_tls_enabled" {
  description = "Enable TLS for Dify application"
  type        = bool
  default     = true
}



# Monitoring Stack
variable "install_monitoring_stack" {
  description = "Install Prometheus and Grafana monitoring stack"
  type        = bool
  default     = false
}

variable "prometheus_stack_version" {
  description = "Prometheus stack Helm chart version"
  type        = string
  default     = "54.0.1"
}

# ──────────────── Dify EE Plugin Configuration ────────────────

variable "dify_plugin_api_key" {
  description = "API key for Dify plugin daemon and connector"
  type        = string
  default     = "dify123456"
  sensitive   = true
}

variable "dify_plugin_inner_api_key" {
  description = "Inner API key for Dify plugin daemon"
  type        = string
  default     = "QaHbTe77CtuXmsfyhR7+vRjI/+XbV1AaFy691iy+kGDv2Jvy0/eAh8Y1"
  sensitive   = true
}

variable "dify_app_secret_key" {
  description = "Secret key for Dify application"
  type        = string
  sensitive   = true
}

variable "dify_admin_api_secret_key_salt" {
  description = "Secret key salt for Dify admin APIs"
  type        = string
  sensitive   = true
}

variable "dify_sandbox_api_key" {
  description = "API key for Dify sandbox service"
  type        = string
  sensitive   = true
}

variable "dify_inner_api_key" {
  description = "Inner API key for Dify API service"
  type        = string
  sensitive   = true
}

variable "create_plugin_daemon_database" {
  description = "Create dify_plugin_daemon database"
  type        = bool
  default     = true
}