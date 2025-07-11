# terraform/modules/lambda-failover/outputs.tf
output "lambda_function_arn" {
  value       = aws_lambda_function.failover_orchestrator.arn
  description = "ARN of the failover Lambda function"
}

output "lambda_function_name" {
  value       = aws_lambda_function.failover_orchestrator.function_name
  description = "Name of the failover Lambda function"
}

output "event_rule_name" {
  value       = aws_cloudwatch_event_rule.failover_trigger.name
  description = "EventBridge rule name for failover trigger"
}