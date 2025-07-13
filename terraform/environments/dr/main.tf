# terraform/environments/dr/main.tf

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
    key            = "dr/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "student-record-system-v2-terraform-locks"
    encrypt        = true
  }
}

# Provider configuration for DR region
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

# Provider for primary region (to access resources)
provider "aws" {
  alias  = "primary"
  region = "eu-central-1"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Check if production resources exist (for first deployment)
data "aws_ssm_parameter" "database_cluster_arn" {
  provider = aws.primary
  name     = "/${var.project_name}/production/database-cluster-arn"

  # This makes the data source optional - won't fail if doesn't exist
  count = var.skip_read_replica ? 0 : 1
}

# Create networking infrastructure (without NAT gateways to save costs)
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
  create_nat_gateways   = false # No NAT gateways in DR (pilot light)
}

# Create security groups
module "security" {
  source = "../../modules/security"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.networking.vpc_id
  allow_replication_cidrs = ["10.2.0.0/16"] # Allow replication from production VPC
}

# Create ECR repository in DR region - FIXED
module "ecr" {
  source = "../../modules/ecr"

  project_name                    = var.project_name
  environment                     = var.environment
  enable_cross_region_replication = false

}

# Create RDS Aurora - either read replica or standalone
module "database" {
  source = "../../modules/database"

  project_name       = var.project_name
  environment        = var.environment
  subnet_ids         = module.networking.private_subnet_ids
  security_group_id  = module.security.rds_security_group_id
  database_name      = var.database_name
  master_username    = var.database_username
  master_password    = var.database_password
  instance_class     = "db.r5.large" # Smaller instance for DR
  is_read_replica    = var.skip_read_replica ? false : true
  source_cluster_arn = var.skip_read_replica ? "" : data.aws_ssm_parameter.database_cluster_arn[0].value
}

# Create S3 buckets (destination for replication)
module "s3" {
  source = "../../modules/s3"

  project_name       = var.project_name
  environment        = var.environment
  enable_replication = false # This is the destination
}

# Create Application Load Balancer (pre-created for quick failover)
module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  certificate_arn       = var.acm_certificate_arn
}

# Create ECS cluster and service (with 0 desired count for pilot light)
module "ecs" {
  source = "../../modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  ecr_repository_url    = module.ecr.repository_url           # ✅ Use DR region ECR
  private_subnet_ids    = module.networking.public_subnet_ids # Use public subnets since no NAT
  ecs_security_group_id = module.security.ecs_security_group_id
  target_group_arn      = module.alb.target_group_arn
  database_endpoint     = module.database.cluster_endpoint
  database_name         = var.database_name
  db_secret_arn         = module.database.db_secret_arn
  desired_count         = 0 # Start with 0 for pilot light
  min_capacity          = 0
  max_capacity          = 10
  task_cpu              = "256"
  task_memory           = "512"
  assign_public_ip      = true # Need public IP since no NAT gateway

}

# Store DR endpoints for failover script and CloudFront
resource "aws_ssm_parameter" "dr_alb_dns" {
  name  = "/${var.project_name}/dr/alb-dns-name"
  type  = "String"
  value = module.alb.alb_dns_name
}

resource "aws_ssm_parameter" "dr_database_endpoint" {
  name  = "/${var.project_name}/dr/database-endpoint"
  type  = "String"
  value = module.database.cluster_endpoint
}

resource "aws_ssm_parameter" "dr_ecs_cluster_name" {
  name  = "/${var.project_name}/dr/ecs-cluster-name"
  type  = "String"
  value = module.ecs.cluster_name
}

resource "aws_ssm_parameter" "dr_ecs_service_name" {
  name  = "/${var.project_name}/dr/ecs-service-name"
  type  = "String"
  value = module.ecs.service_name
}

# Store DR ECR repository URL for image replication
resource "aws_ssm_parameter" "dr_ecr_repository_url" {
  name  = "/${var.project_name}/dr/ecr-repository-url"
  type  = "String"
  value = module.ecr.repository_url
}

# Parameter for failover status
resource "aws_ssm_parameter" "failover_in_progress" {
  name  = "/${var.project_name}/failover/in-progress"
  type  = "String"
  value = "false"
}

# CloudWatch Dashboard for DR monitoring
resource "aws_cloudwatch_dashboard" "dr" {
  dashboard_name = "${var.project_name}-dr-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", module.database.cluster_id],
            [".", "CPUUtilization", ".", "."],
            [".", "ReadLatency", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Metrics"
        }
      },
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
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", split(":", module.alb.target_group_arn)[5], "LoadBalancer", split("/", module.alb.alb_arn)[2]],
            [".", "UnHealthyHostCount", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "DR ALB Target Health"
        }
      }
    ]
  })
}

# CloudWatch Alarm for DR readiness
resource "aws_cloudwatch_metric_alarm" "dr_readiness" {
  alarm_name          = "${var.project_name}-dr-readiness-check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"
  alarm_description   = "DR RDS health check"
  treat_missing_data  = "breaching"

  dimensions = {
    DBClusterIdentifier = module.database.cluster_id
  }
}