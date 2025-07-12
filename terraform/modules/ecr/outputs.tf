# terraform/modules/ecr/outputs.tf

output "repository_url" {
  value       = data.aws_ecr_repository.main.repository_url
  description = "URL of the ECR repository"
}

output "repository_arn" {
  value       = data.aws_ecr_repository.main.arn
  description = "ARN of the ECR repository"
}

output "repository_name" {
  value       = data.aws_ecr_repository.main.name
  description = "Name of the ECR repository"
}