output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "DNS name of the DR Application Load Balancer"
}

output "database_endpoint" {
  value       = module.database.cluster_endpoint
  description = "DR Aurora cluster endpoint"
}

output "ecs_cluster_name" {
  value       = module.ecs.cluster_name
  description = "Name of the DR ECS cluster"
}

output "ecs_service_name" {
  value       = module.ecs.service_name
  description = "Name of the DR ECS service"
}

output "dr_ready" {
  value       = "DR infrastructure is ready in pilot light mode"
  description = "DR readiness status"
}