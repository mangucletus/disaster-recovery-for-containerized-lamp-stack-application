variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "student_db"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "master_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "Instance class for Aurora instances"
  type        = string
  default     = "db.t4g.medium"
}

variable "instance_count" {
  description = "Number of Aurora instances"
  type        = number
  default     = 1
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "is_read_replica" {
  description = "Whether this is a read replica setup"
  type        = bool
  default     = false
}

variable "source_cluster_arn" {
  description = "ARN of the source cluster for read replica"
  type        = string
  default     = ""
}