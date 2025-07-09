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
  instance_class          = "db.t3.medium"
  instance_count          = 2 # 2 instances for HA
  backup_retention_period = 7
  is_read_replica         = false
}

# Create S3 buckets
module "s3" {
  source = "../../modules/s3"

  project_name           = var.project_name
  environment            = var.environment
  enable_replication     = true
  destination_bucket_arn = "arn:aws:s3:::${var.project_name}-assets-dr-${data.aws_caller_identity.current.account_id}"
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
  enable_access_logs    = true
  access_logs_bucket    = module.s3.assets_bucket_id
}

# Create CloudFront distribution after ALB is created
module "cloudfront" {
  source = "../../modules/cloudfront"
  
  project_name        = var.project_name
  environment         = var.environment
  primary_alb_dns_name = module.alb.alb_dns_name
  dr_alb_dns_name     = "YOUR-DR-ALB-DNS-NAME"  # You'll get this after DR deployment
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

# Create Route53 DNS records (if domain is available)
module "route53" {
  source = "../../modules/route53"
  count  = var.route53_hosted_zone_id != "" ? 1 : 0

  project_name         = var.project_name
  hosted_zone_id       = var.route53_hosted_zone_id
  domain_name          = var.domain_name
  subdomain            = var.subdomain
  primary_alb_dns_name = module.alb.alb_dns_name
  primary_alb_zone_id  = module.alb.alb_zone_id
  create_health_check  = true
}

# Store important outputs in Parameter Store for DR region
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

# CloudWatch Alarms
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