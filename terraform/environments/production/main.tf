# Production Environment - Primary Region (eu-central-1)

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for state management
  backend "s3" {
    bucket         = "student-record-system-v2-terraform-state-216989132235"
    key            = "production/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "student-record-system-v2-terraform-locks"
    encrypt        = true
  }
}

# Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Provider for DR region (to get DR ALB DNS)
provider "aws" {
  alias  = "dr"
  region = "eu-west-1"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Create networking infrastructure
module "networking" {
  source = "../../modules/networking"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  public_subnet_1_cidr  = var.public_subnet_1_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
  create_nat_gateways   = true # Create NAT gateways in production
}

# Create security groups
module "security" {
  source = "../../modules/security"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.networking.vpc_id
  allow_replication_cidrs = ["10.3.0.0/16"] # Allow replication from DR VPC
}

# Create ECR repository
module "ecr" {
  source = "../../modules/ecr"

  project_name                    = var.project_name
  environment                     = var.environment
  enable_cross_region_replication = true
}

# Create RDS Aurora database
module "database" {
  source = "../../modules/database"

  project_name            = var.project_name
  environment             = var.environment
  subnet_ids              = module.networking.private_subnet_ids
  security_group_id       = module.security.rds_security_group_id
  database_name           = var.database_name
  master_username         = var.database_username
  master_password         = var.database_password
  instance_class          = "db.r5.large"
  instance_count          = 2 # 2 instances for HA
  backup_retention_period = 7
  is_read_replica         = false
}

# Create S3 buckets
module "s3" {
  source = "../../modules/s3"

  project_name           = var.project_name
  environment            = var.environment
  enable_replication     = var.enable_s3_replication
  destination_bucket_arn = var.enable_s3_replication ? "arn:aws:s3:::${var.project_name}-assets-dr-${data.aws_caller_identity.current.account_id}" : ""
  # destination_bucket_arn = "arn:aws:s3:::${var.project_name}-assets-dr-${data.aws_caller_identity.current.account_id}"
}

# Create Application Load Balancer
module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  certificate_arn       = var.acm_certificate_arn
  enable_access_logs    = false  # Disabled to avoid permission issues
  access_logs_bucket    = ""     # Empty since we're not using it
}

# Create ECS cluster and service
module "ecs" {
  source = "../../modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  ecr_repository_url    = module.ecr.repository_url
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.security.ecs_security_group_id
  target_group_arn      = module.alb.target_group_arn
  database_endpoint     = module.database.cluster_endpoint
  database_name         = var.database_name
  db_secret_arn         = module.database.db_secret_arn
  desired_count         = 2
  min_capacity          = 2
  max_capacity          = 10
  task_cpu              = "256"
  task_memory           = "512"
  
}

# Store important outputs in Parameter Store for DR region and Lambda
resource "aws_ssm_parameter" "database_cluster_arn" {
  name  = "/${var.project_name}/production/database-cluster-arn"
  type  = "String"
  value = module.database.cluster_arn
}

resource "aws_ssm_parameter" "ecr_repository_url" {
  name  = "/${var.project_name}/production/ecr-repository-url"
  type  = "String"
  value = module.ecr.repository_url
}

resource "aws_ssm_parameter" "target_group_arn" {
  name  = "/${var.project_name}/primary/target-group-arn"
  type  = "String"
  value = module.alb.target_group_arn
}

resource "aws_ssm_parameter" "primary_alb_dns" {
  name  = "/${var.project_name}/primary/alb-dns-name"
  type  = "String"
  value = module.alb.alb_dns_name
}




# Get DR ALB DNS from parameter store (created by DR deployment)
# data "aws_ssm_parameter" "dr_alb_dns" {
#   provider = aws.dr
#   name     = "/${var.project_name}/dr/alb-dns-name"

#   # This will fail on first run, so we make it optional
#   depends_on = [aws_ssm_parameter.primary_alb_dns]
# }
# ✅ Use local variable with try() to avoid failure on first deployment

# locals {
#   dr_alb_dns_fallback = "placeholder.elb.eu-west-1.amazonaws.com"

#   dr_alb_dns = try(
#     data.aws_ssm_parameter.dr_alb_dns.value,
#     local.dr_alb_dns_fallback
#   )
# }

# Only now define the data block (optional – not always needed)
# data "aws_ssm_parameter" "dr_alb_dns" {
#   provider = aws.dr
#   name     = "/${var.project_name}/dr/alb-dns-name"
# }


# locals {
#   dr_alb_dns_fallback = "placeholder.elb.eu-west-1.amazonaws.com"

#   dr_alb_dns = try(
#     data.aws_ssm_parameter.dr_alb_dns.value,
#     local.dr_alb_dns_fallback
#   )
# }

# This must go AFTER the locals block
# data "aws_ssm_parameter" "dr_alb_dns" {
#   provider = aws.dr
#   name     = "/${var.project_name}/dr/alb-dns-name"
# }

locals {
  # DR ALB DNS fallback value used on first deploy
  dr_alb_dns_name = "placeholder.elb.eu-west-1.amazonaws.com"
}


# Create CloudFront distribution for automatic failover
# NOTE: This should be deployed AFTER the DR environment is set up
# Comment this out on first deployment, then uncomment after DR is ready
module "cloudfront" {
  source = "../../modules/cloudfront"

  project_name         = var.project_name
  environment          = var.environment
  primary_alb_dns_name = module.alb.alb_dns_name
  primary_alb_arn      = module.alb.alb_arn
  dr_alb_dns_name = local.dr_alb_dns_name

  #dr_alb_dns_name      = try(data.aws_ssm_parameter.dr_alb_dns.value, "placeholder.elb.eu-west-1.amazonaws.com")
  primary_region       = var.aws_region
  dr_region            = "eu-west-1"
}

# Create Lambda for automatic failover orchestration
# This should also be deployed after DR is ready
module "lambda_failover" {
  source = "../../modules/lambda-failover"

  project_name              = var.project_name
  environment               = var.environment
  primary_region            = var.aws_region
  dr_region                 = "eu-west-1"
  sns_topic_arn             = module.cloudfront.sns_topic_arn
  dr_ecs_cluster_name       = "${var.project_name}-cluster"
  dr_ecs_service_name       = "${var.project_name}-service"
  dr_rds_cluster_identifier = "${var.project_name}-aurora-cluster-replica"
  primary_alb_alarm_name    = module.cloudfront.primary_alarm_name

  depends_on = [module.cloudfront]
}

# CloudWatch Alarms for monitoring in the region
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors ECS CPU utilization"

  dimensions = {
    ServiceName = module.ecs.service_name
    ClusterName = module.ecs.cluster_name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_unhealthy" {
  alarm_name          = "${var.project_name}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors ALB unhealthy targets"

  dimensions = {
    TargetGroup  = split(":", module.alb.target_group_arn)[5]
    LoadBalancer = split("/", module.alb.alb_arn)[2]
  }
}

# Store CloudFront URL in Parameter Store for easy access
resource "aws_ssm_parameter" "cloudfront_url" {
  name  = "/${var.project_name}/cloudfront-url"
  type  = "String"
  value = try(module.cloudfront.cloudfront_url, "not-deployed")

  depends_on = [module.cloudfront]
}

resource "aws_ssm_parameter" "cloudfront_distribution_id" {
  name  = "/${var.project_name}/cloudfront-distribution-id"
  type  = "String"
  value = try(module.cloudfront.cloudfront_distribution_id, "not-deployed")

  depends_on = [module.cloudfront]
}

resource "aws_cloudwatch_dashboard" "ecs_dashboard" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", module.ecs.service_name, "ClusterName", module.ecs.cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Service Metrics"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", split("/", module.alb.alb_arn)[2]],
            [".", "HealthyHostCount", ".", ".", { stat = "Average" }],
            [".", "UnHealthyHostCount", ".", ".", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      }
    ]
  })
}


