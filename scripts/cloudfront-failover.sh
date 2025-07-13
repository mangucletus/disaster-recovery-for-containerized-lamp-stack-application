#!/bin/bash
# scripts/cloudfront-failover.sh
# Manual failover script for CloudFront distribution

set -e

PROJECT_NAME="student-record-system-v2"
PRIMARY_REGION="eu-central-1"
DR_REGION="eu-west-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 CloudFront Manual Failover Script${NC}"
echo "=================================="

# Get CloudFront distribution ID
DISTRIBUTION_ID=$(aws ssm get-parameter --name "/$PROJECT_NAME/cloudfront-distribution-id" --region $PRIMARY_REGION --query 'Parameter.Value' --output text 2>/dev/null)

if [ "$DISTRIBUTION_ID" = "None" ] || [ -z "$DISTRIBUTION_ID" ]; then
    echo -e "${RED}❌ Could not find CloudFront distribution ID${NC}"
    exit 1
fi

echo "📡 Distribution ID: $DISTRIBUTION_ID"

# Get current distribution config
echo "📥 Getting current distribution configuration..."
aws cloudfront get-distribution-config --id $DISTRIBUTION_ID > /tmp/cf-config.json

# Extract ETag and config
ETAG=$(jq -r '.ETag' /tmp/cf-config.json)
jq '.DistributionConfig' /tmp/cf-config.json > /tmp/cf-dist-config.json

# Get current primary origin target
CURRENT_TARGET=$(jq -r '.DefaultCacheBehavior.TargetOriginId' /tmp/cf-dist-config.json)

echo "🎯 Current target: $CURRENT_TARGET"

# Determine failover action
if [ "$CURRENT_TARGET" = "primary-alb" ]; then
    NEW_TARGET="dr-alb"
    ACTION="FAILOVER TO DR"
    echo -e "${YELLOW}🚨 Failing over to DR region ($DR_REGION)${NC}"
elif [ "$CURRENT_TARGET" = "dr-alb" ]; then
    NEW_TARGET="primary-alb"
    ACTION="FAILBACK TO PRIMARY"
    echo -e "${GREEN}✅ Failing back to Primary region ($PRIMARY_REGION)${NC}"
else
    echo -e "${RED}❌ Unknown current target: $CURRENT_TARGET${NC}"
    exit 1
fi

# Confirm action
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will redirect ALL traffic!${NC}"
echo "Action: $ACTION"
echo "From: $CURRENT_TARGET"
echo "To: $NEW_TARGET"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted"
    exit 1
fi

# Update the configuration
echo "📝 Updating distribution configuration..."
jq --arg new_target "$NEW_TARGET" '.DefaultCacheBehavior.TargetOriginId = $new_target' /tmp/cf-dist-config.json > /tmp/cf-updated-config.json

# Apply the update
echo "🚀 Applying configuration update..."
aws cloudfront update-distribution \
    --id $DISTRIBUTION_ID \
    --distribution-config file:///tmp/cf-updated-config.json \
    --if-match $ETAG > /tmp/cf-update-result.json

NEW_ETAG=$(jq -r '.ETag' /tmp/cf-update-result.json)
DEPLOY_ID=$(jq -r '.Distribution.Id' /tmp/cf-update-result.json)

echo "✅ Configuration updated successfully!"
echo "📋 New ETag: $NEW_ETAG"
echo "🆔 Deploy ID: $DEPLOY_ID"

# Monitor deployment status
echo ""
echo "⏳ Waiting for distribution deployment to complete..."
echo "   This usually takes 15-20 minutes..."

aws cloudfront wait distribution-deployed --id $DISTRIBUTION_ID

echo ""
echo -e "${GREEN}🎉 FAILOVER COMPLETED SUCCESSFULLY!${NC}"
echo "=================================="
echo "✅ Target: $NEW_TARGET"
echo "🌐 Distribution: $DISTRIBUTION_ID"
echo "⏰ Completed at: $(date)"

# Store failover state
aws ssm put-parameter \
    --name "/$PROJECT_NAME/failover/current-target" \
    --value "$NEW_TARGET" \
    --type "String" \
    --overwrite \
    --region $PRIMARY_REGION

aws ssm put-parameter \
    --name "/$PROJECT_NAME/failover/last-timestamp" \
    --value "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --type "String" \
    --overwrite \
    --region $PRIMARY_REGION

echo ""
echo "📊 Test the application:"
CF_URL=$(aws ssm get-parameter --name "/$PROJECT_NAME/cloudfront-url" --region $PRIMARY_REGION --query 'Parameter.Value' --output text)
echo "🔗 https://$CF_URL"

# Cleanup temp files
rm -f /tmp/cf-*.json

echo ""
echo -e "${GREEN}✅ Failover completed successfully!${NC}"