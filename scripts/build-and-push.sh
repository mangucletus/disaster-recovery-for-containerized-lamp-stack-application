#!/bin/bash
# Build and push Docker image to ECR

set -e

# Configuration
PROJECT_NAME="student-record-system-v2"
AWS_REGION="eu-central-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME"

echo "🐳 Building Docker image..."

# Change to docker directory
cd docker

# Build the image
docker build -t $PROJECT_NAME:latest .

# Tag the image
docker tag $PROJECT_NAME:latest $ECR_REPOSITORY:latest

echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY

echo "📤 Pushing image to ECR..."
docker push $ECR_REPOSITORY:latest

echo "✅ Docker image pushed successfully!"
echo "Image URI: $ECR_REPOSITORY:latest"