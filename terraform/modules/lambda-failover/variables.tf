# terraform/modules/lambda-failover/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "dr_region" {
  description = "DR AWS region"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
}

variable "dr_ecs_cluster_name" {
  description = "DR ECS cluster name"
  type        = string
}

variable "dr_ecs_service_name" {
  description = "DR ECS service name"
  type        = string
}

variable "dr_rds_cluster_identifier" {
  description = "DR RDS cluster identifier"
  type        = string
}

variable "primary_alb_alarm_name" {
  description = "Primary ALB CloudWatch alarm name"
  type        = string
}

