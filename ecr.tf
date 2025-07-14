# ECR Repository
resource "aws_ecr_repository" "dify" {
  name                 = "dify-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "dify-${var.environment}-ecr"
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