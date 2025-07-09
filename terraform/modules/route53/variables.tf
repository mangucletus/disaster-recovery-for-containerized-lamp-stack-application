variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = ""
}

variable "subdomain" {
  description = "Subdomain"
  type        = string
  default     = ""
}

variable "primary_alb_dns_name" {
  description = "DNS name of primary ALB"
  type        = string
}

variable "primary_alb_zone_id" {
  description = "Zone ID of primary ALB"
  type        = string
}

variable "dr_alb_dns_name" {
  description = "DNS name of DR ALB"
  type        = string
  default     = ""
}

variable "dr_alb_zone_id" {
  description = "Zone ID of DR ALB"
  type        = string
  default     = ""
}

variable "create_health_check" {
  description = "Create Route53 health checks"
  type        = bool
  default     = true
}