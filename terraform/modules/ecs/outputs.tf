output "cluster_id" {
  value       = aws_ecs_cluster.main.id
  description = "ECS cluster ID"
}

output "cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "ECS cluster name"
}

output "service_name" {
  value       = aws_ecs_service.main.name
  description = "ECS service name"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.main.arn
  description = "Task definition ARN"
}