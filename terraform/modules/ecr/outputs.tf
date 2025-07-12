output "repository_url" {
  value       = local.repository_url
  description = "URL of the ECR repository"
}

output "repository_arn" {
  value       = local.repository_arn
  description = "ARN of the ECR repository"
}

output "repository_name" {
  value       = local.repository_name
  description = "Name of the ECR repository"
}
