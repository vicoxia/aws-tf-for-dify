locals {
  s3_storage_gb = var.environment == "test" ? 100 : 512
}

# S3 Bucket for Dify storage
resource "aws_s3_bucket" "dify_storage" {
  bucket = "dify-${var.environment}-storage-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "dify-${var.environment}-storage"
    Environment = var.environment
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "dify_storage" {
  bucket = aws_s3_bucket.dify_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dify_storage" {
  bucket = aws_s3_bucket.dify_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dify_storage" {
  bucket = aws_s3_bucket.dify_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ──────────────── Dify EE IRSA Roles ────────────────

# 1. S3-only role for dify-api ServiceAccount
resource "aws_iam_role" "dify_ee_s3_role" {
  name = "DifyEE-Role-${aws_eks_cluster.main.name}-s3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      }
    ]
  })

  tags = {
    Name        = "DifyEE-S3-Role-${var.environment}"
    Environment = var.environment
    Purpose     = "DifyEE-S3-Access"
  }
}

# 2. S3 + ECR role for dify-plugin-crd ServiceAccount
resource "aws_iam_role" "dify_ee_s3_ecr_role" {
  name = "DifyEE-Role-${aws_eks_cluster.main.name}-s3-ecr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      }
    ]
  })

  tags = {
    Name        = "DifyEE-S3-ECR-Role-${var.environment}"
    Environment = var.environment
    Purpose     = "DifyEE-S3-ECR-Access"
  }
}

# 3. ECR image pull role for dify-plugin-runner ServiceAccount
resource "aws_iam_role" "dify_ee_ecr_pull_role" {
  name = "DifyEE-Role-${aws_eks_cluster.main.name}-ecr-image-pull"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      }
    ]
  })

  tags = {
    Name        = "DifyEE-ECR-Pull-Role-${var.environment}"
    Environment = var.environment
    Purpose     = "DifyEE-ECR-Image-Pull"
  }
}

# ──────────────── IAM Policies ────────────────

# S3 policy for bucket access
resource "aws_iam_policy" "dify_ee_s3_policy" {
  name = "dify-ee-irsa-${aws_eks_cluster.main.name}-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = "arn:aws:s3:::${aws_s3_bucket.dify_storage.bucket}/*"
      }
    ]
  })

  tags = {
    Name        = "DifyEE-S3-Policy-${var.environment}"
    Environment = var.environment
  }
}

# ECR full access policy
resource "aws_iam_policy" "dify_ee_ecr_policy" {
  name = "dify-ee-irsa-${aws_eks_cluster.main.name}-ecr-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:*",
          "cloudtrail:LookupEvents"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "DifyEE-ECR-Policy-${var.environment}"
    Environment = var.environment
  }
}

# ECR pull-only policy
resource "aws_iam_policy" "dify_ee_ecr_pull_only_policy" {
  name = "dify-ee-irsa-${aws_eks_cluster.main.name}-ecr-pull-only-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ecr:BatchGetImage"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "DifyEE-ECR-Pull-Policy-${var.environment}"
    Environment = var.environment
  }
}

# ──────────────── Policy Attachments ────────────────

# Attach S3 policy to S3-only role
resource "aws_iam_role_policy_attachment" "dify_ee_s3_role_s3_policy" {
  role       = aws_iam_role.dify_ee_s3_role.name
  policy_arn = aws_iam_policy.dify_ee_s3_policy.arn
}

# Attach S3 and ECR policies to S3+ECR role
resource "aws_iam_role_policy_attachment" "dify_ee_s3_ecr_role_s3_policy" {
  role       = aws_iam_role.dify_ee_s3_ecr_role.name
  policy_arn = aws_iam_policy.dify_ee_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "dify_ee_s3_ecr_role_ecr_policy" {
  role       = aws_iam_role.dify_ee_s3_ecr_role.name
  policy_arn = aws_iam_policy.dify_ee_ecr_policy.arn
}

# Attach ECR pull-only policy to ECR pull role
resource "aws_iam_role_policy_attachment" "dify_ee_ecr_pull_role_policy" {
  role       = aws_iam_role.dify_ee_ecr_pull_role.name
  policy_arn = aws_iam_policy.dify_ee_ecr_pull_only_policy.arn
}

# ──────────────── Legacy S3 Access Role (for backward compatibility) ────────────────
resource "aws_iam_role" "s3_access" {
  name = "dify-${var.environment}-s3-access-role"

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
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:default:dify-s3-service-account"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_access" {
  name = "dify-${var.environment}-s3-access-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.dify_storage.arn,
          "${aws_s3_bucket.dify_storage.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.s3_access.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# OIDC Provider for EKS
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name        = "dify-${var.environment}-eks-oidc"
    Environment = var.environment
  }
}