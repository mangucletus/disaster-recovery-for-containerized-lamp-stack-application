# Project configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "student-record-system-v2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

# Networking configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string
  default     = "10.2.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string
  default     = "10.2.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1"
  type        = string
  default     = "10.2.10.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2"
  type        = string
  default     = "10.2.20.0/24"
}

# Database configuration
variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "student_db"
}

variable "database_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "database_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}

# DNS configuration
variable "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID (optional)"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name (optional)"
  type        = string
  default     = ""
}

variable "subdomain" {
  description = "Subdomain (optional)"
  type        = string
  default     = "app"
}

# SSL certificate
variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS (optional)"
  type        = string
  default     = ""
}

# Add this variable to terraform/environments/production/variables.tf

variable "deploy_cloudfront" {
  description = "Deploy CloudFront and Lambda failover (set to false on first deployment)"
  type        = bool
  default     = false
}

variable "enable_s3_replication" {
  description = "Enable S3 cross-region replication (set to false on first deployment)"
  type        = bool
  default     = false
}