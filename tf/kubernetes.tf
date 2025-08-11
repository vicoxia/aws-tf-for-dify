# ──────────────── Kubernetes资源配置 ────────────────
# 
# 此文件创建Dify应用所需的Kubernetes资源，包括：
# - Dify命名空间
# - IRSA ServiceAccounts（替代 irsa_one_click.sh 脚本的功能）
#

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

# ──────────────── IRSA ServiceAccounts ────────────────
# 
# 以下ServiceAccounts替代了 irsa_one_click.sh 脚本的功能
# 为Dify应用提供AWS资源访问权限
#

# ServiceAccount for dify-api (S3 access only)
resource "kubernetes_service_account" "dify_api" {
  metadata {
    name      = "dify-api-sa"
    namespace = kubernetes_namespace.dify.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.dify_ee_s3_role.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "dify-api"
      "app.kubernetes.io/component"  = "api"
      "app.kubernetes.io/part-of"    = "dify-ee"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.dify_ee_s3_role,
    kubernetes_namespace.dify
  ]
}

# ServiceAccount for dify-plugin-crd (S3 + ECR access)
resource "kubernetes_service_account" "dify_plugin_crd" {
  metadata {
    name      = "dify-plugin-crd-sa"
    namespace = kubernetes_namespace.dify.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.dify_ee_s3_ecr_role.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "dify-plugin-crd"
      "app.kubernetes.io/component"  = "plugin-crd"
      "app.kubernetes.io/part-of"    = "dify-ee"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.dify_ee_s3_ecr_role,
    kubernetes_namespace.dify
  ]
}

# ServiceAccount for dify-plugin-runner (ECR image pull only)
resource "kubernetes_service_account" "dify_plugin_runner" {
  metadata {
    name      = "dify-plugin-runner-sa"
    namespace = kubernetes_namespace.dify.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.dify_ee_ecr_pull_role.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "dify-plugin-runner"
      "app.kubernetes.io/component"  = "plugin-runner"
      "app.kubernetes.io/part-of"    = "dify-ee"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.dify_ee_ecr_pull_role,
    kubernetes_namespace.dify
  ]
}

# ServiceAccount for dify-plugin-connector (S3 access for plugin connector)
resource "kubernetes_service_account" "dify_plugin_connector" {
  metadata {
    name      = "dify-plugin-connector-sa"
    namespace = kubernetes_namespace.dify.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.dify_ee_s3_role.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "dify-plugin-connector"
      "app.kubernetes.io/component"  = "plugin-connector"
      "app.kubernetes.io/part-of"    = "dify-ee"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.dify_ee_s3_role,
    kubernetes_namespace.dify
  ]
}

# Alternative ServiceAccount names for compatibility with upgrade guide
# These are aliases for the ServiceAccounts with names mentioned in the upgrade guide

resource "kubernetes_service_account" "dify_plugin_build" {
  metadata {
    name      = "dify-plugin-build-sa"
    namespace = kubernetes_namespace.dify.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.dify_ee_s3_ecr_role.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "dify-plugin-build"
      "app.kubernetes.io/component"  = "plugin-build"
      "app.kubernetes.io/part-of"    = "dify-ee"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.dify_ee_s3_ecr_role,
    kubernetes_namespace.dify
  ]
}

resource "kubernetes_service_account" "dify_plugin_build_run" {
  metadata {
    name      = "dify-plugin-build-run-sa"
    namespace = kubernetes_namespace.dify.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.dify_ee_ecr_pull_role.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "dify-plugin-build-run"
      "app.kubernetes.io/component"  = "plugin-build-run"
      "app.kubernetes.io/part-of"    = "dify-ee"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role.dify_ee_ecr_pull_role,
    kubernetes_namespace.dify
  ]
}

# ──────────────── Namespace for Dify EE (optional) ────────────────
# Uncomment if you want to deploy Dify EE in a separate namespace

# resource "kubernetes_namespace" "dify_ee" {
#   metadata {
#     name = "dify-ee"
#     labels = {
#       "app.kubernetes.io/name"       = "dify-ee"
#       "app.kubernetes.io/managed-by" = "terraform"
#     }
#   }
# }

# # ServiceAccounts in dify-ee namespace
# resource "kubernetes_service_account" "dify_api_ee_ns" {
#   metadata {
#     name      = "dify-api-sa"
#     namespace = kubernetes_namespace.dify_ee.metadata[0].name
#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.dify_ee_s3_role.arn
#     }
#   }
#   depends_on = [aws_eks_cluster.main]
# }

# resource "kubernetes_service_account" "dify_plugin_crd_ee_ns" {
#   metadata {
#     name      = "dify-plugin-crd-sa"
#     namespace = kubernetes_namespace.dify_ee.metadata[0].name
#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.dify_ee_s3_ecr_role.arn
#     }
#   }
#   depends_on = [aws_eks_cluster.main]
# }

# resource "kubernetes_service_account" "dify_plugin_runner_ee_ns" {
#   metadata {
#     name      = "dify-plugin-runner-sa"
#     namespace = kubernetes_namespace.dify_ee.metadata[0].name
#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.dify_ee_ecr_pull_role.arn
#     }
#   }
#   depends_on = [aws_eks_cluster.main]
# }