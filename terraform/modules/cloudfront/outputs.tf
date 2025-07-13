# terraform/modules/cloudfront/outputs.tf
output "cloudfront_url" {
  value       = aws_cloudfront_distribution.failover.domain_name
  description = "CloudFront distribution URL"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.failover.id
  description = "CloudFront distribution ID"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.failover_notifications.arn
  description = "SNS topic ARN for failover notifications"
}

output "primary_alarm_name" {
  value       = aws_cloudwatch_metric_alarm.primary_alb_unhealthy.alarm_name
  description = "Primary ALB health alarm name"
}