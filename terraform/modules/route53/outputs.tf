output "primary_health_check_id" {
  value       = var.create_health_check ? aws_route53_health_check.primary[0].id : null
  description = "ID of primary health check"
}

output "dr_health_check_id" {
  value       = var.create_health_check && var.dr_alb_dns_name != "" ? aws_route53_health_check.dr[0].id : null
  description = "ID of DR health check"
}

output "fqdn" {
  value       = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  description = "Fully qualified domain name"
}