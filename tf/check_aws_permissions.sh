#!/bin/bash

# AWS permissions check script
# Used to verify AWS permissions required for deploying Dify Enterprise Edition

set -e

echo "🔍 AWS Permissions Check Script"
echo "==============================="

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is configured
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not installed${NC}"
    exit 1
fi

# Get current user information
echo "📋 Getting current user information..."
CALLER_IDENTITY=$(aws sts get-caller-identity 2>/dev/null)
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ AWS CLI not configured or credentials invalid${NC}"
    echo "Please run: aws configure"
    exit 1
fi

# Extract user information
USER_ARN=$(echo "$CALLER_IDENTITY" | jq -r '.Arn')
ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | jq -r '.Account')
USER_ID=$(echo "$CALLER_IDENTITY" | jq -r '.UserId')

echo "📊 User Information: Account ID: $ACCOUNT_ID"

# Check user type (user or role)
if [[ $USER_ARN == *":user/"* ]]; then
    USER_TYPE="user"
    USER_NAME=$(echo "$USER_ARN" | cut -d'/' -f2)
    echo "   Type: IAM User ($USER_NAME)"
elif [[ $USER_ARN == *":role/"* ]]; then
    USER_TYPE="role"
    ROLE_NAME=$(echo "$USER_ARN" | cut -d'/' -f2)
    echo "   Type: IAM Role ($ROLE_NAME)"
else
    echo -e "${YELLOW}⚠️  Unknown user type${NC}"
fi

echo ""
echo "🔐 Checking permission policies..."

# Check user permissions (if IAM user)
if [ "$USER_TYPE" = "user" ]; then
    # Simplified policy check, only show key information
    ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "$USER_NAME" --query 'AttachedPolicies[].PolicyName' --output text 2>/dev/null || echo "Unable to retrieve")
    if [ "$ATTACHED_POLICIES" != "Unable to retrieve" ] && [ -n "$ATTACHED_POLICIES" ]; then
        echo "   Attached Policies: $ATTACHED_POLICIES"
    fi
    
    USER_GROUPS=$(aws iam get-groups-for-user --user-name "$USER_NAME" --query 'Groups[].GroupName' --output text 2>/dev/null || echo "")
    if [ -n "$USER_GROUPS" ]; then
        echo "   User Groups: $USER_GROUPS"
    fi
fi

echo ""
echo "🧪 Testing key service permissions..."

# Define services and commands to test
REGION=${AWS_REGION:-us-west-2}

# Test permissions for each service
echo "Checking EKS permissions..."
if aws eks list-clusters --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}EKS permissions OK${NC}"
else
    echo -e "❌ ${RED}EKS permissions missing or insufficient${NC}"
fi

echo "Checking RDS permissions..."
if aws rds describe-db-clusters --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}RDS permissions OK${NC}"
else
    echo -e "❌ ${RED}RDS permissions missing or insufficient${NC}"
fi

echo "Checking EC2 permissions..."
if aws ec2 describe-vpcs --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}EC2 permissions OK${NC}"
else
    echo -e "❌ ${RED}EC2 permissions missing or insufficient${NC}"
fi

echo "Checking IAM permissions..."
if aws iam list-roles --max-items 1 > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}IAM permissions OK${NC}"
else
    echo -e "❌ ${RED}IAM permissions missing or insufficient${NC}"
fi

echo "Checking S3 permissions..."
if aws s3 ls > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}S3 permissions OK${NC}"
else
    echo -e "❌ ${RED}S3 permissions missing or insufficient${NC}"
fi

echo "Checking ElastiCache permissions..."
if aws elasticache describe-cache-clusters --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}ElastiCache permissions OK${NC}"
else
    echo -e "❌ ${RED}ElastiCache permissions missing or insufficient${NC}"
fi

echo "Checking OpenSearch permissions..."
if aws opensearch list-domain-names --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}OpenSearch permissions OK${NC}"
else
    echo -e "❌ ${RED}OpenSearch permissions missing or insufficient${NC}"
fi

echo "Checking ECR permissions..."
if aws ecr describe-repositories --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}ECR permissions OK${NC}"
else
    echo -e "❌ ${RED}ECR permissions missing or insufficient${NC}"
fi

echo ""
echo "📍 Checking region availability..."

if aws ec2 describe-availability-zones --region "$REGION" > /dev/null 2>&1; then
    AZ_COUNT=$(aws ec2 describe-availability-zones --region "$REGION" --query 'length(AvailabilityZones)' --output text)
    echo -e "✅ ${GREEN}Region $REGION available ($AZ_COUNT availability zones)${NC}"
else
    echo -e "❌ ${RED}Cannot access region $REGION${NC}"
fi

echo ""
echo "📋 Permission Check Summary"
echo "==========================="

# Check if has administrator permissions
HAS_ADMIN=false
if [ "$USER_TYPE" = "user" ]; then
    if aws iam list-attached-user-policies --user-name "$USER_NAME" 2>/dev/null | grep -q "AdministratorAccess" || \
       aws iam get-groups-for-user --user-name "$USER_NAME" 2>/dev/null | grep -q "AdministratorAccess"; then
        HAS_ADMIN=true
    fi
fi

if [ "$HAS_ADMIN" = true ]; then
    echo -e "✅ ${GREEN}Administrator permissions detected - can deploy Dify Enterprise Edition${NC}"
else
    echo -e "⚠️  ${YELLOW}Complete administrator permissions not detected${NC}"
    echo "   Required permissions: EC2, EKS, RDS, ElastiCache, OpenSearch, S3, IAM, ECR"
fi

echo ""
echo "🚀 Next step: $([ "$HAS_ADMIN" = true ] && echo "terraform init" || echo "Contact AWS administrator to add permissions")"

echo ""
echo "✨ Permission check completed!"