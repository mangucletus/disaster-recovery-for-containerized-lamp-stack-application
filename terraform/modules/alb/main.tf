# ALB Module - Creates Application Load Balancer and Target Group

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  # Enable deletion protection for production
  enable_deletion_protection = var.environment == "production" ? true : false

  # Disable access logs by default to avoid permission issues
  # Enable only if bucket exists and has proper permissions
  dynamic "access_logs" {
    for_each = var.enable_access_logs && var.access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = "alb-logs"
      enabled = true
    }
  }

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# S3 bucket policy for ALB access logs (only if enabled)
resource "aws_s3_bucket_policy" "alb_logs" {
  count  = var.enable_access_logs && var.access_logs_bucket != "" ? 1 : 0
  bucket = var.access_logs_bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.access_logs_bucket}/alb-logs/*"
      }
    ]
  })
}

# Get the AWS ELB service account for the current region
data "aws_elb_service_account" "main" {}

# Target Group
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Target type for Fargate
  target_type = "ip"

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  # Deregistration delay for graceful shutdown
  deregistration_delay = 30

  # Stickiness configuration
  stickiness {
    enabled         = true
    type            = "lb_cookie"
    cookie_duration = 86400 # 24 hours
  }

  tags = {
    Name        = "${var.project_name}-tg"
    Environment = var.environment
  }
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# HTTPS Listener (optional, requires certificate)
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# HTTP to HTTPS redirect (if HTTPS is enabled)
resource "aws_lb_listener_rule" "redirect_http_to_https" {
  count = var.certificate_arn != "" ? 1 : 0

  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}