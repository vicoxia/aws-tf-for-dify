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

echo "$CALLER_IDENTITY"

# 提取用户信息
USER_ARN=$(echo "$CALLER_IDENTITY" | jq -r '.Arn')
ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | jq -r '.Account')
USER_ID=$(echo "$CALLER_IDENTITY" | jq -r '.UserId')

echo ""
echo "📊 用户信息:"
echo "Account ID: $ACCOUNT_ID"
echo "User ARN: $USER_ARN"
echo "User ID: $USER_ID"

# 检查用户类型（用户还是角色）
if [[ $USER_ARN == *":user/"* ]]; then
    USER_TYPE="user"
    USER_NAME=$(echo "$USER_ARN" | cut -d'/' -f2)
    echo "User Type: IAM User"
    echo "User Name: $USER_NAME"
elif [[ $USER_ARN == *":role/"* ]]; then
    USER_TYPE="role"
    ROLE_NAME=$(echo "$USER_ARN" | cut -d'/' -f2)
    echo "User Type: IAM Role"
    echo "Role Name: $ROLE_NAME"
else
    echo -e "${YELLOW}⚠️  未知的用户类型${NC}"
fi

echo ""
echo "🔐 检查权限策略..."

# 检查用户权限（如果是IAM用户）
if [ "$USER_TYPE" = "user" ]; then
    echo "检查用户附加的策略..."
    aws iam list-attached-user-policies --user-name "$USER_NAME" 2>/dev/null || echo "无法获取用户策略"
    
    echo ""
    echo "检查用户内联策略..."
    aws iam list-user-policies --user-name "$USER_NAME" 2>/dev/null || echo "无法获取内联策略"
    
    echo ""
    echo "检查用户所属组..."
    aws iam get-groups-for-user --user-name "$USER_NAME" 2>/dev/null || echo "无法获取用户组信息"
fi

echo ""
echo "🧪 测试关键服务权限..."

# 定义需要测试的服务
declare -A services=(
    ["EKS"]="aws eks list-clusters --region ${AWS_REGION:-us-west-2}"
    ["RDS"]="aws rds describe-db-clusters --region ${AWS_REGION:-us-west-2}"
    ["EC2"]="aws ec2 describe-vpcs --region ${AWS_REGION:-us-west-2}"
    ["IAM"]="aws iam list-roles --max-items 1"
    ["S3"]="aws s3 ls"
    ["ElastiCache"]="aws elasticache describe-cache-clusters --region ${AWS_REGION:-us-west-2}"
    ["OpenSearch"]="aws opensearch list-domain-names --region ${AWS_REGION:-us-west-2}"
    ["ECR"]="aws ecr describe-repositories --region ${AWS_REGION:-us-west-2}"
)

# 测试每个服务的权限
for service in "${!services[@]}"; do
    command="${services[$service]}"
    if eval "$command" > /dev/null 2>&1; then
        echo -e "✅ ${GREEN}$service permissions OK${NC}"
    else
        echo -e "❌ ${RED}$service permissions missing or insufficient${NC}"
    fi
done

echo ""
echo "📍 检查区域可用性..."
REGION=${AWS_REGION:-us-west-2}
echo "当前区域: $REGION"

if aws ec2 describe-availability-zones --region "$REGION" > /dev/null 2>&1; then
    AZ_COUNT=$(aws ec2 describe-availability-zones --region "$REGION" --query 'length(AvailabilityZones)' --output text)
    echo -e "✅ ${GREEN}区域 $REGION 可用，包含 $AZ_COUNT 个可用区${NC}"
else
    echo -e "❌ ${RED}无法访问区域 $REGION${NC}"
fi

echo ""
echo "💰 检查账户限制..."

# 检查一些关键的服务限制
echo "检查EKS集群限制..."
if aws service-quotas get-service-quota --service-code eks --quota-code L-1194D53C --region "$REGION" > /dev/null 2>&1; then
    EKS_LIMIT=$(aws service-quotas get-service-quota --service-code eks --quota-code L-1194D53C --region "$REGION" --query 'Quota.Value' --output text 2>/dev/null || echo "未知")
    echo "EKS集群限制: $EKS_LIMIT"
else
    echo "无法获取EKS限制信息"
fi

echo ""
echo "📋 权限检查总结"
echo "================"

# 检查是否有管理员权限
if aws iam list-attached-user-policies --user-name "$USER_NAME" 2>/dev/null | grep -q "AdministratorAccess" || \
   aws iam get-groups-for-user --user-name "$USER_NAME" 2>/dev/null | grep -q "AdministratorAccess"; then
    echo -e "✅ ${GREEN}检测到管理员权限${NC}"
    echo "✅ 应该可以成功部署Dify企业版"
else
    echo -e "⚠️  ${YELLOW}未检测到完整的管理员权限${NC}"
    echo "请确保用户具有以下服务的完整权限："
    echo "  - EC2 (VPC, 子网, 安全组)"
    echo "  - EKS"
    echo "  - RDS"
    echo "  - ElastiCache"
    echo "  - OpenSearch"
    echo "  - S3"
    echo "  - IAM"
    echo "  - ECR"
fi

echo ""
echo "🚀 下一步操作:"
echo "1. 如果权限检查通过，可以继续执行: terraform init"
echo "2. 如果权限不足，请联系AWS管理员添加必要权限"
echo "3. 建议的IAM策略: AdministratorAccess 或自定义策略包含上述服务的完整权限"

echo ""
echo "权限检查完成！"