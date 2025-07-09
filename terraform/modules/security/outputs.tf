output "alb_security_group_id" {
  value       = aws_security_group.alb.id
  description = "Security group ID for ALB"
}

output "ecs_security_group_id" {
  value       = aws_security_group.ecs_tasks.id
  description = "Security group ID for ECS tasks"
}

output "rds_security_group_id" {
  value       = aws_security_group.rds.id
  description = "Security group ID for RDS"
}