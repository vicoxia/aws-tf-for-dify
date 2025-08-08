# ──────────────── Helm Chart Deployments ────────────────

# Create namespace for Dify application
resource "kubernetes_namespace" "dify" {
  metadata {
    name = var.dify_namespace
    labels = {
      "app.kubernetes.io/name"       = "dify"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_cluster.main]
}

# ──────────────── AWS Load Balancer Controller ────────────────
# This is required for ALB/NLB ingress support

resource "helm_release" "aws_load_balancer_controller" {
  count = var.install_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller[0].arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = local.vpc_id
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.aws_load_balancer_controller
  ]
}

# IAM role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.install_aws_load_balancer_controller ? 1 : 0

  name = "AmazonEKSLoadBalancerControllerRole-${aws_eks_cluster.main.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "AWSLoadBalancerControllerRole-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = var.install_aws_load_balancer_controller ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}

# ──────────────── NGINX Ingress Controller (Alternative to ALB) ────────────────

resource "helm_release" "nginx_ingress" {
  count = var.install_nginx_ingress ? 1 : 0

  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.nginx_ingress_version
  namespace  = "ingress-nginx"

  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
    value = "true"
  }

  depends_on = [aws_eks_cluster.main]
}

# ──────────────── Cert-Manager for SSL Certificates ────────────────

resource "helm_release" "cert_manager" {
  count = var.install_cert_manager ? 1 : 0

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  namespace  = "cert-manager"

  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  depends_on = [aws_eks_cluster.main]
}

# ──────────────── Dify Application Helm Chart ────────────────

resource "helm_release" "dify" {
  count = var.install_dify_chart ? 1 : 0

  name       = "dify"
  repository = var.dify_helm_repo_url
  chart      = var.dify_helm_chart_name
  version    = var.dify_helm_chart_version
  namespace  = kubernetes_namespace.dify.metadata[0].name

  # Global configuration
  set {
    name  = "global.edition"
    value = "SELF_HOSTED"
  }

  set_sensitive {
    name  = "global.appSecretKey"
    value = var.dify_app_secret_key
  }

  set {
    name  = "global.useTLS"
    value = var.dify_tls_enabled
  }

  set {
    name  = "global.consoleApiDomain"
    value = var.dify_hostname
  }

  set {
    name  = "global.consoleWebDomain"
    value = var.dify_hostname
  }

  set {
    name  = "global.serviceApiDomain"
    value = var.dify_hostname
  }

  set {
    name  = "global.appApiDomain"
    value = var.dify_hostname
  }

  set {
    name  = "global.appWebDomain"
    value = var.dify_hostname
  }

  set {
    name  = "global.filesDomain"
    value = var.dify_hostname
  }

  set {
    name  = "global.enterpriseDomain"
    value = var.dify_hostname
  }

  set {
    name  = "global.dbMigrationEnabled"
    value = "true"
  }

  # Database configuration
  set {
    name  = "postgresql.enabled"
    value = "false"  # Use external Aurora
  }

  # External PostgreSQL configuration
  set {
    name  = "externalPostgres.enabled"
    value = "true"
  }

  set {
    name  = "externalPostgres.address"
    value = aws_rds_cluster.main.endpoint
  }

  set {
    name  = "externalPostgres.port"
    value = "5432"
  }

  # Dify main database
  set {
    name  = "externalPostgres.credentials.dify.database"
    value = aws_rds_cluster.main.database_name
  }

  set {
    name  = "externalPostgres.credentials.dify.username"
    value = var.rds_username
  }

  set_sensitive {
    name  = "externalPostgres.credentials.dify.password"
    value = var.rds_password
  }

  set {
    name  = "externalPostgres.credentials.dify.sslmode"
    value = "disable"
  }

  # Plugin daemon database
  set {
    name  = "externalPostgres.credentials.plugin_daemon.database"
    value = "dify_plugin_daemon"
  }

  set {
    name  = "externalPostgres.credentials.plugin_daemon.username"
    value = var.rds_username
  }

  set_sensitive {
    name  = "externalPostgres.credentials.plugin_daemon.password"
    value = var.rds_password
  }

  set {
    name  = "externalPostgres.credentials.plugin_daemon.sslmode"
    value = "disable"
  }

  # Enterprise database
  set {
    name  = "externalPostgres.credentials.enterprise.database"
    value = "dify_enterprise"
  }

  set {
    name  = "externalPostgres.credentials.enterprise.username"
    value = var.rds_username
  }

  set_sensitive {
    name  = "externalPostgres.credentials.enterprise.password"
    value = var.rds_password
  }

  set {
    name  = "externalPostgres.credentials.enterprise.sslmode"
    value = "disable"
  }

  # Audit database
  set {
    name  = "externalPostgres.credentials.audit.database"
    value = "dify_audit"
  }

  set {
    name  = "externalPostgres.credentials.audit.username"
    value = var.rds_username
  }

  set_sensitive {
    name  = "externalPostgres.credentials.audit.password"
    value = var.rds_password
  }

  set {
    name  = "externalPostgres.credentials.audit.sslmode"
    value = "disable"
  }

  # Redis configuration
  set {
    name  = "redis.enabled"
    value = "false"  # Use external ElastiCache
  }

  set {
    name  = "externalRedis.enabled"
    value = "true"
  }

  set {
    name  = "externalRedis.host"
    value = aws_elasticache_cluster.main.cache_nodes[0].address
  }

  set {
    name  = "externalRedis.port"
    value = "6379"
  }

  set {
    name  = "externalRedis.db"
    value = "0"
  }

  # Storage configuration
  set {
    name  = "persistence.type"
    value = "s3"
  }

  set {
    name  = "persistence.s3.bucketName"
    value = aws_s3_bucket.dify_storage.bucket
  }

  set {
    name  = "persistence.s3.region"
    value = var.aws_region
  }

  set {
    name  = "persistence.s3.useAwsS3"
    value = "true"
  }

  set {
    name  = "persistence.s3.useAwsManagedIam"
    value = "true"
  }

  # Vector Database configuration (OpenSearch)
  set {
    name  = "vectorDB.useExternal"
    value = "true"
  }

  set {
    name  = "vectorDB.externalType"
    value = "opensearch"
  }

  set {
    name  = "vectorDB.externalOpenSearch.host"
    value = aws_opensearch_domain.main.endpoint
  }

  set {
    name  = "vectorDB.externalOpenSearch.port"
    value = "443"
  }

  set {
    name  = "vectorDB.externalOpenSearch.useTLS"
    value = "true"
  }

  set_sensitive {
    name  = "vectorDB.externalOpenSearch.user"
    value = var.opensearch_admin_name
  }

  set_sensitive {
    name  = "vectorDB.externalOpenSearch.password"
    value = var.opensearch_password
  }

  # ECR configuration
  set {
    name  = "image.repository"
    value = aws_ecr_repository.dify.repository_url
  }

  set {
    name  = "image.tag"
    value = var.dify_image_tag
  }

  # ServiceAccount configuration for IRSA
  set {
    name  = "api.serviceAccount.create"
    value = "false"  # Use pre-created ServiceAccount
  }

  set {
    name  = "api.serviceAccount.name"
    value = kubernetes_service_account.dify_api.metadata[0].name
  }

  set {
    name  = "api.serviceAccountName"
    value = kubernetes_service_account.dify_api.metadata[0].name
  }

  set {
    name  = "worker.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "worker.serviceAccount.name"
    value = kubernetes_service_account.dify_api.metadata[0].name
  }

  set {
    name  = "worker.serviceAccountName"
    value = kubernetes_service_account.dify_api.metadata[0].name
  }

  # Plugin daemon configuration
  set {
    name  = "plugin_daemon.enabled"
    value = "true"
  }

  set {
    name  = "plugin_daemon.replicas"
    value = "1"
  }

  set_sensitive {
    name  = "plugin_daemon.apiKey"
    value = var.dify_plugin_api_key
  }

  set {
    name  = "plugin_daemon.maxLaunchSeconds"
    value = "3600"
  }

  set {
    name  = "plugin_daemon.forceVerifyingSignature"
    value = "false"
  }

  set {
    name  = "plugin_daemon.serviceType"
    value = "ClusterIP"
  }

  set {
    name  = "plugin_daemon.pluginExecuteTimeout"
    value = "360"
  }

  set_sensitive {
    name  = "plugin_daemon.innerApiKey"
    value = var.dify_plugin_inner_api_key
  }

  # Plugin controller configuration
  set {
    name  = "plugin_controller.replicas"
    value = "1"
  }

  # Plugin connector configuration
  set {
    name  = "plugin_connector.replicas"
    value = "1"
  }

  set_sensitive {
    name  = "plugin_connector.apiKey"
    value = var.dify_plugin_api_key
  }

  set {
    name  = "plugin_connector.maxWaitSeconds"
    value = "3600"
  }

  set {
    name  = "plugin_connector.customServiceAccount"
    value = kubernetes_service_account.dify_plugin_build.metadata[0].name
  }

  set {
    name  = "plugin_connector.runnerServiceAccount"
    value = kubernetes_service_account.dify_plugin_build_run.metadata[0].name
  }

  set {
    name  = "plugin_connector.insecureImageRepo"
    value = "false"
  }

  set {
    name  = "plugin_connector.imageRepoPrefix"
    value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/dify-ee"
  }

  set {
    name  = "plugin_connector.imageRepoType"
    value = "ecr"
  }

  set {
    name  = "plugin_connector.ecrRegion"
    value = var.aws_region
  }

  set {
    name  = "plugin_connector.pluginResourceLimits.cpu"
    value = "1000m"
  }

  set {
    name  = "plugin_connector.pluginResourceLimits.memory"
    value = "500Mi"
  }

  set {
    name  = "plugin_connector.pluginResourceRequests.cpu"
    value = "100m"
  }

  set {
    name  = "plugin_connector.pluginResourceRequests.memory"
    value = "50Mi"
  }

  # Enterprise components configuration
  set {
    name  = "enterprise.enabled"
    value = "true"
  }

  set {
    name  = "enterprise.replicas"
    value = var.environment == "prod" ? "2" : "1"
  }

  set_sensitive {
    name  = "enterprise.appSecretKey"
    value = var.dify_app_secret_key
  }

  set_sensitive {
    name  = "enterprise.adminAPIsSecretKeySalt"
    value = var.dify_admin_api_secret_key_salt
  }

  set {
    name  = "enterprise.serviceAccountName"
    value = kubernetes_service_account.dify_api.metadata[0].name
  }

  set {
    name  = "enterprise.licenseMode"
    value = "online"
  }

  set {
    name  = "enterpriseAudit.enabled"
    value = "true"
  }

  set {
    name  = "enterpriseAudit.replicas"
    value = "1"
  }

  set {
    name  = "enterpriseFrontend.enabled"
    value = "true"
  }

  set {
    name  = "enterpriseFrontend.replicas"
    value = var.environment == "prod" ? "2" : "1"
  }

  set {
    name  = "gateway.replicas"
    value = "1"
  }

  # Sandbox configuration
  set {
    name  = "sandbox.enabled"
    value = "true"
  }

  set {
    name  = "sandbox.replicas"
    value = "1"
  }

  set_sensitive {
    name  = "sandbox.apiKey"
    value = var.dify_sandbox_api_key
  }

  # SSRF Proxy configuration
  set {
    name  = "ssrfProxy.enabled"
    value = "true"
  }

  set {
    name  = "ssrfProxy.replicas"
    value = "1"
  }

  # Unstructured service configuration
  set {
    name  = "unstructured.enabled"
    value = "true"
  }

  set {
    name  = "unstructured.replicas"
    value = "1"
  }

  # API configuration
  set {
    name  = "api.deployEnv"
    value = var.environment == "prod" ? "PRODUCTION" : "DEVELOPMENT"
  }

  set {
    name  = "api.webApiCorsAllowOrigins"
    value = "*"
  }

  set {
    name  = "api.consoleCorsAllowOrigins"
    value = "*"
  }

  set {
    name  = "api.serverWorkerAmount"
    value = var.environment == "prod" ? "2" : "1"
  }

  set_sensitive {
    name  = "api.innerApi.apiKey"
    value = var.dify_inner_api_key
  }

  # Ingress configuration
  set {
    name  = "ingress.enabled"
    value = var.dify_ingress_enabled
  }

  set {
    name  = "ingress.className"
    value = var.dify_ingress_class
  }

  set {
    name  = "ingress.hostname"
    value = var.dify_hostname
  }

  set {
    name  = "ingress.tls"
    value = var.dify_tls_enabled
  }

  # Environment-specific resource limits
  dynamic "set" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      name  = "api.resources.requests.memory"
      value = "2Gi"
    }
  }

  dynamic "set" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      name  = "api.resources.requests.cpu"
      value = "1000m"
    }
  }

  dynamic "set" {
    for_each = var.environment == "test" ? [1] : []
    content {
      name  = "api.resources.requests.memory"
      value = "1Gi"
    }
  }

  dynamic "set" {
    for_each = var.environment == "test" ? [1] : []
    content {
      name  = "api.resources.requests.cpu"
      value = "500m"
    }
  }

  # Use official Dify values.yaml file
  values = [file("${path.module}/helm-values/values.yaml")]

  depends_on = [
    aws_eks_cluster.main,
    aws_rds_cluster.main,
    aws_elasticache_cluster.main,
    aws_opensearch_domain.main,
    kubernetes_service_account.dify_api,
    kubernetes_namespace.dify,
    helm_release.aws_load_balancer_controller,
    helm_release.nginx_ingress
  ]
}



# ──────────────── Monitoring Stack (Optional) ────────────────

resource "helm_release" "prometheus_stack" {
  count = var.install_monitoring_stack ? 1 : 0

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = "monitoring"

  create_namespace = true

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.environment == "prod" ? "50Gi" : "20Gi"
  }

  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  set {
    name  = "grafana.persistence.size"
    value = var.environment == "prod" ? "10Gi" : "5Gi"
  }

  depends_on = [aws_eks_cluster.main]
}