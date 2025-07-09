output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "DNS name of the Application Load Balancer"
}

output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "URL of the ECR repository"
}

output "database_endpoint" {
  value       = module.database.cluster_endpoint
  description = "Aurora cluster endpoint"
}

output "database_cluster_arn" {
  value       = module.database.cluster_arn
  description = "Aurora cluster ARN"
}

output "ecs_cluster_name" {
  value       = module.ecs.cluster_name
  description = "Name of the ECS cluster"
}

output "ecs_service_name" {
  value       = module.ecs.service_name
  description = "Name of the ECS service"
}