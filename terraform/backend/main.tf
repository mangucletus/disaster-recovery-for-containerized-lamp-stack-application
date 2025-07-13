# This file creates the S3 bucket and DynamoDB table for Terraform state management
# Run this FIRST before any other Terraform configurations

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider for eu-central-1 (primary region)
provider "aws" {
  region = "eu-central-1"
}

# S3 bucket for storing Terraform state files (best practice)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "student-record-system-v2-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "global"
    Purpose     = "Store Terraform state files"
  }
}

# Enable versioning for state file protection
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for security
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to the state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "student-record-system-v2-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "global"
    Purpose     = "Prevent concurrent Terraform operations"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Output the backend configuration for use in other Terraform files
output "backend_config" {
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    region         = "eu-central-1"
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
  }

  description = "Backend configuration for other Terraform projects"
}