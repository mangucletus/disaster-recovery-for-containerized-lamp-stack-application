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

# CloudFront distribution WITHOUT origin groups (to allow POST methods)
resource "aws_cloudfront_distribution" "failover" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name} - Distribution with Manual Failover"

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

  # Secondary origin - DR ALB (for manual failover)
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

  # Default cache behavior - Points to primary origin and allows all methods
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-alb" # Use primary origin directly
    compress         = true

    forwarded_values {
      query_string = true
      headers      = ["*"] # Forward all headers

      cookies {
        forward = "all" # Forward all cookies for session management
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0 # No caching for dynamic content
    max_ttl                = 86400
  }

  # Cache behavior for static assets
  ordered_cache_behavior {
    path_pattern     = "/assets/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-alb"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  # Cache behavior for CSS files
  ordered_cache_behavior {
    path_pattern     = "*.css"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-alb"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 86400
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  # Cache behavior for JS files
  ordered_cache_behavior {
    path_pattern     = "*.js"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-alb"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 86400
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  # Cache behavior for image files
  ordered_cache_behavior {
    path_pattern     = "*.png"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-alb"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 86400
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  # Custom error pages
  custom_error_response {
    error_code            = 502
    response_code         = 503
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 503
    response_code         = 503
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 504
    response_code         = 504
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.project_name}-cloudfront"
    Environment = var.environment
    Purpose     = "Primary Distribution - Manual DR Failover"
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