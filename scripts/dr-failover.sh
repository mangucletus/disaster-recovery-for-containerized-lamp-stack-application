#!/bin/bash
# DR Failover Script - Activates DR environment

set -e

# Configuration
PROJECT_NAME="student-record-system-v2"
DR_REGION="eu-west-1"

echo "🚨 Starting DR Failover Process..."
echo "⚠️  This will activate the DR environment in $DR_REGION"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Failover cancelled."
    exit 1
fi

echo ""
echo "📊 Step 1: Checking DR infrastructure status..."
# Get DR parameters
DR_CLUSTER=$(aws ssm get-parameter --name "/$PROJECT_NAME/dr/ecs-cluster-name" --region $DR_REGION --query 'Parameter.Value' --output text)
DR_SERVICE=$(aws ssm get-parameter --name "/$PROJECT_NAME/dr/ecs-service-name" --region $DR_REGION --query 'Parameter.Value' --output text)
DR_ALB=$(aws ssm get-parameter --name "/$PROJECT_NAME/dr/alb-dns-name" --region $DR_REGION --query 'Parameter.Value' --output text)

echo "DR Cluster: $DR_CLUSTER"
echo "DR Service: $DR_SERVICE"
echo "DR ALB: $DR_ALB"

echo ""
echo "🔄 Step 2: Promoting RDS Read Replica..."
# Note: This is a manual step in the AWS Console or requires specific cluster identifier
echo "⚠️  Please promote the RDS read replica to a standalone cluster in the AWS Console"
echo "   Region: $DR_REGION"
echo "   Cluster: $PROJECT_NAME-aurora-cluster-replica"
read -p "Press enter when the read replica has been promoted..."

echo ""
echo "🚀 Step 3: Scaling up ECS service..."
aws ecs update-service \
    --cluster $DR_CLUSTER \
    --service $DR_SERVICE \
    --desired-count 2 \
    --region $DR_REGION

echo "Waiting for ECS service to stabilize..."
aws ecs wait services-stable \
    --cluster $DR_CLUSTER \
    --services $DR_SERVICE \
    --region $DR_REGION

echo ""
echo "✅ Step 4: Verifying DR environment..."
# Check ECS service status
RUNNING_COUNT=$(aws ecs describe-services \
    --cluster $DR_CLUSTER \
    --services $DR_SERVICE \
    --region $DR_REGION \
    --query 'services[0].runningCount' \
    --output text)

echo "Running tasks: $RUNNING_COUNT"

echo ""
echo "🌐 Step 5: Update DNS (if using Route53)..."
echo "The Route53 health checks should automatically failover to DR if configured."
echo "If manual DNS update is needed, update your DNS records to point to:"
echo "DR ALB: $DR_ALB"

echo ""
echo "📝 DR Failover Summary:"
echo "========================"
echo "DR Region: $DR_REGION"
echo "DR ALB URL: http://$DR_ALB"
echo "ECS Running Tasks: $RUNNING_COUNT"
echo ""
echo "✅ DR failover completed successfully!"
echo ""
echo "⚠️  Important Next Steps:"
echo "1. Verify application functionality at http://$DR_ALB"
echo "2. Update any external services to use the new endpoints"
echo "3. Monitor CloudWatch dashboards for any issues"
echo "4. Document the incident and failover time"