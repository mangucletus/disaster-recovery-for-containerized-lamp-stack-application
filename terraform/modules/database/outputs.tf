output "cluster_endpoint" {
  value       = var.is_read_replica ? aws_rds_cluster.read_replica[0].endpoint : aws_rds_cluster.main[0].endpoint
  description = "Aurora cluster endpoint"
}

output "cluster_arn" {
  value       = var.is_read_replica ? aws_rds_cluster.read_replica[0].arn : aws_rds_cluster.main[0].arn
  description = "Aurora cluster ARN"
}

output "cluster_id" {
  value       = var.is_read_replica ? aws_rds_cluster.read_replica[0].id : aws_rds_cluster.main[0].id
  description = "Aurora cluster ID"
}

output "db_secret_arn" {
  value       = aws_secretsmanager_secret.db_password.arn
  description = "ARN of the Secrets Manager secret for DB credentials"
}
