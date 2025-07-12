# terraform/modules/cloudfront/main.tf

# Create CloudWatch alarms for primary ALB health
resource "aws_cloudwatch_metric_alarm" "primary_alb_unhealthy" {
  alarm_name          = "${var.project_name}-primary-alb-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Primary ALB has unhealthy targets"
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = split("/", var.primary_alb_arn)[2]
  }

  alarm_actions = [aws_sns_topic.failover_notifications.arn]
}

# SNS topic for failover notifications
resource "aws_sns_topic" "failover_notifications" {
  name = "${var.project_name}-failover-notifications"
}

# CloudFront distribution with origin failover
resource "aws_cloudfront_distribution" "failover" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name} - Automatic Failover Distribution"

  # Primary origin - Production ALB
  origin {
    domain_name = var.primary_alb_dns_name
    origin_id   = "primary-alb"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }

    custom_header {
      name  = "X-Origin-Region"
      value = var.primary_region
    }
  }

  # Secondary origin - DR ALB
  origin {
    domain_name = var.dr_alb_dns_name
    origin_id   = "dr-alb"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }

    custom_header {
      name  = "X-Origin-Region"
      value = var.dr_region
    }
  }

  # Origin group with automatic failover
  origin_group {
    origin_id = "alb-group"

    failover_criteria {
      status_codes = [500, 502, 503, 504, 403, 404]
    }

    member {
      origin_id = "primary-alb"
    }

    member {
      origin_id = "dr-alb"
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"] 
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-group" # Use the origin group

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  # Custom error pages for better failover experience
  custom_error_response {
    error_code         = 502
    response_code      = 200
    response_page_path = "/index.php"
  }

  custom_error_response {
    error_code         = 503
    response_code      = 200
    response_page_path = "/index.php"
  }

  custom_error_response {
    error_code         = 504
    response_code      = 200
    response_page_path = "/index.php"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Web ACL for additional security (optional)
  # web_acl_id = var.web_acl_id

  tags = {
    Name        = "${var.project_name}-cloudfront"
    Environment = var.environment
    Purpose     = "Automatic DR Failover"
  }
}

# Create CloudWatch dashboard for monitoring
resource "aws_cloudwatch_dashboard" "failover_monitoring" {
  dashboard_name = "${var.project_name}-failover-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "OriginLatency", "DistributionId", aws_cloudfront_distribution.failover.id, "OriginId", "primary-alb"],
            [".", ".", ".", ".", ".", "dr-alb"]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "Origin Latency"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", aws_cloudfront_distribution.failover.id],
            [".", "5xxErrorRate", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "Error Rates"
        }
      }
    ]
  })
}