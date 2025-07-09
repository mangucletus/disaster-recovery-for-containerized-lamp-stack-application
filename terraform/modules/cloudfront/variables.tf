variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., production, staging, dr)"
  type        = string
}

variable "primary_alb_dns_name" {
  description = "DNS name of the primary (production) Application Load Balancer"
  type        = string
}

variable "dr_alb_dns_name" {
  description = "DNS name of the disaster recovery (DR) Application Load Balancer"
  type        = string
}
