# ECR Repository for main Dify application
resource "aws_ecr_repository" "dify" {
  name                 = "${var.prefix}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.prefix}-${var.environment}-ecr"
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "dify" {
  repository = aws_ecr_repository.dify.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository for Dify EE plugins
resource "aws_ecr_repository" "dify_ee_plugin" {
  name                 = "${var.prefix}-ee-plugin-repo-${lower(replace(aws_eks_cluster.main.name, "_", "-"))}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.prefix}-${var.environment}-ee-plugin-ecr"
    Environment = var.environment
    Purpose     = "DifyEE-Plugin-Storage"
  }
}

resource "aws_ecr_lifecycle_policy" "dify_ee_plugin" {
  repository = aws_ecr_repository.dify_ee_plugin.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 plugin images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}