# terraform/environments/dr/variables.tf

# Project configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "student-record-system-v2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dr"
}

variable "aws_region" {
  description = "AWS region for DR"
  type        = string
  default     = "eu-west-1"
}

# Networking configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.3.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string
  default     = "10.3.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string
  default     = "10.3.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1"
  type        = string
  default     = "10.3.10.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2"
  type        = string
  default     = "10.3.20.0/24"
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

# SSL certificate
variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS in eu-west-1 (optional)"
  type        = string
  default     = ""
}

variable "skip_read_replica" {
  description = "Skip creating read replica (for first deployment when production doesn't exist)"
  type        = bool
  default     = false
}