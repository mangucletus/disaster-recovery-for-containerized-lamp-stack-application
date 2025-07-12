# terraform/modules/ecr/main.tf
# Use existing ECR repository created by GitHub Actions

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Reference existing ECR repository (created by GitHub Actions)
data "aws_ecr_repository" "main" {
  name = var.project_name
}

# ECR Lifecycle Policy (only if we want to manage it via Terraform)
resource "aws_ecr_lifecycle_policy" "main" {
  repository = data.aws_ecr_repository.main.name

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
}

# ECR Repository Policy - Allow cross-region access for DR
resource "aws_ecr_repository_policy" "cross_region" {
  count      = var.enable_cross_region_replication ? 1 : 0
  repository = data.aws_ecr_repository.main.name

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
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
      }
    ]
  })
}