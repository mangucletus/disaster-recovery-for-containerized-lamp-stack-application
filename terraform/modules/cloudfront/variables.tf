# terraform/modules/cloudfront/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "primary_alb_dns_name" {
  description = "DNS name of the primary ALB"
  type        = string
}

variable "primary_alb_arn" {
  description = "ARN of the primary ALB"
  type        = string
}

variable "dr_alb_dns_name" {
  description = "DNS name of the DR ALB"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "dr_region" {
  description = "DR AWS region"
  type        = string
  default     = "eu-west-1"
}

