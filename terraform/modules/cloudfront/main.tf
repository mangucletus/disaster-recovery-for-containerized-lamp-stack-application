# terraform/modules/cloudfront/main.tf

# Create CloudFront distribution with origin failover
resource "aws_cloudfront_distribution" "failover" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name} - Automatic Failover Distribution"
  
  # Primary origin - Production ALB
  origin {
    domain_name = var.primary_alb_dns_name
    origin_id   = "primary-alb"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    
    custom_header {
      name  = "X-Origin-Region"
      value = "eu-central-1"
    }
  }
  
  # Secondary origin - DR ALB
  origin {
    domain_name = var.dr_alb_dns_name
    origin_id   = "dr-alb"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    
    custom_header {
      name  = "X-Origin-Region"
      value = "eu-west-1"
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
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-group"  # Use the origin group
    
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
  }
}

