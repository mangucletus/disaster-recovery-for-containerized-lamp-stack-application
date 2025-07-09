# Route53 Module - DNS configuration with failover routing

# Health check for primary ALB
resource "aws_route53_health_check" "primary" {
  count = var.create_health_check ? 1 : 0

  fqdn              = var.primary_alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name        = "${var.project_name}-primary-health-check"
    Environment = "production"
  }
}

# Health check for DR ALB
resource "aws_route53_health_check" "dr" {
  count = var.create_health_check && var.dr_alb_dns_name != "" ? 1 : 0

  fqdn              = var.dr_alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name        = "${var.project_name}-dr-health-check"
    Environment = "dr"
  }
}

# Primary record with failover routing
resource "aws_route53_record" "primary" {
  count = var.hosted_zone_id != "" ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  type    = "A"

  alias {
    name                   = var.primary_alb_dns_name
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }

  set_identifier = "Primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = var.create_health_check ? aws_route53_health_check.primary[0].id : null
}

# DR record with failover routing
resource "aws_route53_record" "dr" {
  count = var.hosted_zone_id != "" && var.dr_alb_dns_name != "" ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  type    = "A"

  alias {
    name                   = var.dr_alb_dns_name
    zone_id                = var.dr_alb_zone_id
    evaluate_target_health = true
  }

  set_identifier = "DR"

  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = var.create_health_check && var.dr_alb_dns_name != "" ? aws_route53_health_check.dr[0].id : null
}