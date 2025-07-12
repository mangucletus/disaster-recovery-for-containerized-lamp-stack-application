# ECR Module - Creates ECR repository for Docker images

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Check if ECR repository already exists
data "aws_ecr_repository" "existing" {
  count = var.check_existing ? 1 : 0
  name  = var.project_name
}

# ECR Repository
resource "aws_ecr_repository" "main" {
  count = var.check_existing && length(data.aws_ecr_repository.existing) > 0 ? 0 : 1
  
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"

  # Enable image scanning on push
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encryption configuration
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-ecr"
    Environment = var.environment
  }
}

# ECR Lifecycle Policy - Keep only last 10 images
resource "aws_ecr_lifecycle_policy" "main" {
  repository = var.check_existing && length(data.aws_ecr_repository.existing) > 0 ? data.aws_ecr_repository.existing[0].name : aws_ecr_repository.main[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ECR Repository Policy - Allow cross-region replication for DR
resource "aws_ecr_repository_policy" "cross_region" {
  count      = var.enable_cross_region_replication ? 1 : 0
  repository = var.check_existing && length(data.aws_ecr_repository.existing) > 0 ? data.aws_ecr_repository.existing[0].name : aws_ecr_repository.main[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossRegionReplication"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# Output the repository URL regardless of whether it was created or already existed
locals {
  repository_url = var.check_existing && length(data.aws_ecr_repository.existing) > 0 ? data.aws_ecr_repository.existing[0].repository_url : aws_ecr_repository.main[0].repository_url
  repository_arn = var.check_existing && length(data.aws_ecr_repository.existing) > 0 ? data.aws_ecr_repository.existing[0].arn : aws_ecr_repository.main[0].arn
  repository_name = var.project_name
}