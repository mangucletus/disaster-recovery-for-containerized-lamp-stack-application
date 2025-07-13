# Global provider configuration
# This file defines the provider requirements and default configurations

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Default provider configuration
# This will be overridden in each environment
provider "aws" {
  # Region will be specified in environment-specific configurations

  # Default tags applied to all resources
  default_tags {
    tags = {
      ManagedBy  = "Terraform"
      Project    = "student-record-system-v2"
      Repository = "https://github.com/mangucletus/disaster-recovery-for-containerized-lamp-stack-application.git"
      CostCenter = "Engineering"
      Version    = "2.0"
    }
  }
}

# Provider for random resource generation
provider "random" {
  # No configuration needed
}

# Provider for null resources (used for provisioners)
provider "null" {
  # No configuration needed
}

# Common data sources that can be used across all configurations
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Output common values for reference
output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS Account ID"
}

output "partition" {
  value       = data.aws_partition.current.partition
  description = "AWS Partition"
}