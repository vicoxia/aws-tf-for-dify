#!/bin/bash

# AWS权限检查脚本
# 用于验证部署Dify企业版所需的AWS权限

set -e

echo "🔍 AWS权限检查脚本"
echo "===================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查AWS CLI是否已配置
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI未安装${NC}"
    exit 1
fi

# 获取当前用户信息
echo "📋 获取当前用户信息..."
CALLER_IDENTITY=$(aws sts get-caller-identity 2>/dev/null)
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ AWS CLI未配置或凭证无效${NC}"
    echo "请运行: aws configure"
    exit 1
fi

# 提取用户信息
USER_ARN=$(echo "$CALLER_IDENTITY" | jq -r '.Arn')
ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | jq -r '.Account')
USER_ID=$(echo "$CALLER_IDENTITY" | jq -r '.UserId')

echo "📊 用户信息: Account ID: $ACCOUNT_ID"

# 检查用户类型（用户还是角色）
if [[ $USER_ARN == *":user/"* ]]; then
    USER_TYPE="user"
    USER_NAME=$(echo "$USER_ARN" | cut -d'/' -f2)
    echo "   类型: IAM User ($USER_NAME)"
elif [[ $USER_ARN == *":role/"* ]]; then
    USER_TYPE="role"
    ROLE_NAME=$(echo "$USER_ARN" | cut -d'/' -f2)
    echo "   类型: IAM Role ($ROLE_NAME)"
else
    echo -e "${YELLOW}⚠️  未知的用户类型${NC}"
fi

echo ""
echo "🔐 检查权限策略..."

# 检查用户权限（如果是IAM用户）
if [ "$USER_TYPE" = "user" ]; then
    # 简化策略检查，只显示关键信息
    ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "$USER_NAME" --query 'AttachedPolicies[].PolicyName' --output text 2>/dev/null || echo "无法获取")
    if [ "$ATTACHED_POLICIES" != "无法获取" ] && [ -n "$ATTACHED_POLICIES" ]; then
        echo "   附加策略: $ATTACHED_POLICIES"
    fi
    
    USER_GROUPS=$(aws iam get-groups-for-user --user-name "$USER_NAME" --query 'Groups[].GroupName' --output text 2>/dev/null || echo "")
    if [ -n "$USER_GROUPS" ]; then
        echo "   用户组: $USER_GROUPS"
    fi
fi

echo ""
echo "🧪 测试关键服务权限..."

# 定义需要测试的服务和命令
REGION=${AWS_REGION:-us-west-2}

# 测试每个服务的权限
echo "检查 EKS 权限..."
if aws eks list-clusters --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}EKS permissions OK${NC}"
else
    echo -e "❌ ${RED}EKS permissions missing or insufficient${NC}"
fi

echo "检查 RDS 权限..."
if aws rds describe-db-clusters --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}RDS permissions OK${NC}"
else
    echo -e "❌ ${RED}RDS permissions missing or insufficient${NC}"
fi

echo "检查 EC2 权限..."
if aws ec2 describe-vpcs --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}EC2 permissions OK${NC}"
else
    echo -e "❌ ${RED}EC2 permissions missing or insufficient${NC}"
fi

echo "检查 IAM 权限..."
if aws iam list-roles --max-items 1 > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}IAM permissions OK${NC}"
else
    echo -e "❌ ${RED}IAM permissions missing or insufficient${NC}"
fi

echo "检查 S3 权限..."
if aws s3 ls > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}S3 permissions OK${NC}"
else
    echo -e "❌ ${RED}S3 permissions missing or insufficient${NC}"
fi

echo "检查 ElastiCache 权限..."
if aws elasticache describe-cache-clusters --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}ElastiCache permissions OK${NC}"
else
    echo -e "❌ ${RED}ElastiCache permissions missing or insufficient${NC}"
fi

echo "检查 OpenSearch 权限..."
if aws opensearch list-domain-names --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}OpenSearch permissions OK${NC}"
else
    echo -e "❌ ${RED}OpenSearch permissions missing or insufficient${NC}"
fi

echo "检查 ECR 权限..."
if aws ecr describe-repositories --region "$REGION" > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}ECR permissions OK${NC}"
else
    echo -e "❌ ${RED}ECR permissions missing or insufficient${NC}"
fi

echo ""
echo "📍 检查区域可用性..."

if aws ec2 describe-availability-zones --region "$REGION" > /dev/null 2>&1; then
    AZ_COUNT=$(aws ec2 describe-availability-zones --region "$REGION" --query 'length(AvailabilityZones)' --output text)
    echo -e "✅ ${GREEN}区域 $REGION 可用 ($AZ_COUNT 个可用区)${NC}"
else
    echo -e "❌ ${RED}无法访问区域 $REGION${NC}"
fi

echo ""
echo "📋 权限检查总结"
echo "================"

# 检查是否有管理员权限
HAS_ADMIN=false
if [ "$USER_TYPE" = "user" ]; then
    if aws iam list-attached-user-policies --user-name "$USER_NAME" 2>/dev/null | grep -q "AdministratorAccess" || \
       aws iam get-groups-for-user --user-name "$USER_NAME" 2>/dev/null | grep -q "AdministratorAccess"; then
        HAS_ADMIN=true
    fi
fi

if [ "$HAS_ADMIN" = true ]; then
    echo -e "✅ ${GREEN}检测到管理员权限 - 可以部署Dify企业版${NC}"
else
    echo -e "⚠️  ${YELLOW}未检测到完整的管理员权限${NC}"
    echo "   需要权限: EC2, EKS, RDS, ElastiCache, OpenSearch, S3, IAM, ECR"
fi

echo ""
echo "🚀 下一步: $([ "$HAS_ADMIN" = true ] && echo "terraform init" || echo "联系AWS管理员添加权限")"

echo ""
echo "✨ 权限检查完成！"