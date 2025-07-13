variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "allow_replication_cidrs" {
  description = "CIDR blocks to allow for database replication"
  type        = list(string)
  default     = []
}