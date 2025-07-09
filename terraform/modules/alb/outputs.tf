output "alb_arn" {
  value       = aws_lb.main.arn
  description = "ARN of the load balancer"
}

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "DNS name of the load balancer"
}

output "alb_zone_id" {
  value       = aws_lb.main.zone_id
  description = "Zone ID of the load balancer"
}

output "target_group_arn" {
  value       = aws_lb_target_group.main.arn
  description = "ARN of the target group"
}