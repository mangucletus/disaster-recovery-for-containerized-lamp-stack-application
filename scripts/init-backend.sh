#!/bin/bash
# Initialize Terraform backend - Run this FIRST before any other operations

set -e

echo "🚀 Initializing Terraform Backend..."

# Change to backend directory
cd terraform/backend

# Initialize Terraform
terraform init

# Apply backend configuration
echo "Creating S3 bucket and DynamoDB table for state management..."
terraform apply -auto-approve

# Get outputs
BUCKET=$(terraform output -raw backend_config | jq -r '.bucket')
REGION=$(terraform output -raw backend_config | jq -r '.region')
DYNAMODB_TABLE=$(terraform output -raw backend_config | jq -r '.dynamodb_table')

echo "✅ Backend created successfully!"
echo "Bucket: $BUCKET"
echo "Region: $REGION"
echo "DynamoDB Table: $DYNAMODB_TABLE"

echo ""
echo "📝 Backend configuration has been created. The backend is already configured in the environment main.tf files."