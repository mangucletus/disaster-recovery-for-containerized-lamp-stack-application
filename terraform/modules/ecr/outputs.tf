output "repository_url" {
  value       = try(data.aws_ecr_repository.existing[0].repository_url, aws_ecr_repository.main[0].repository_url, "not-found")
  description = "URL of the ECR repository"
}

output "repository_arn" {
  value       = try(data.aws_ecr_repository.existing[0].arn, aws_ecr_repository.main[0].arn, "not-found")
  description = "ARN of the ECR repository"
}

output "repository_name" {
  value       = try(data.aws_ecr_repository.existing[0].name, aws_ecr_repository.main[0].name, local.repository_name)
  description = "Name of the ECR repository"
}
