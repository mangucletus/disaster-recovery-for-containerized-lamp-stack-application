# variable "project_name" {
#   description = "Name of the project"
#   type        = string
# }

# variable "environment" {
#   description = "Environment name"
#   type        = string
# }

# variable "enable_cross_region_replication" {
#   description = "Enable cross-region replication for DR"
#   type        = bool
#   default     = false
# }

# terraform/modules/ecr/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for DR"
  type        = bool
  default     = false
}

variable "check_existing" {
  description = "Check if ECR repository already exists"
  type        = bool
  default     = true
}

# terraform/modules/ecr/outputs.tf
output "repository_url" {
  value       = local.repository_url
  description = "URL of the ECR repository"
}

output "repository_arn" {
  value       = local.repository_arn
  description = "ARN of the ECR repository"
}

output "repository_name" {
  value       = local.repository_name
  description = "Name of the ECR repository"
}