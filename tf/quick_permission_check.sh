#!/bin/bash

# 快速权限检查脚本 - 修复用户名提取问题

echo "🔍 快速AWS权限检查"
echo "=================="

# 检查AWS CLI配置
echo "1. 检查当前用户身份..."
aws sts get-caller-identity

echo ""
echo "2. 提取用户信息..."

# 正确的方式提取用户名
USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo "User ARN: $USER_ARN"

if [[ $USER_ARN == *":user/"* ]]; then
    USER_NAME=$(echo "$USER_ARN" | cut -d'/' -f2)
    echo "User Name: $USER_NAME"
    
    echo ""
    echo "3. 检查用户权限..."
    
    echo "附加的策略:"
    aws iam list-attached-user-policies --user-name "$USER_NAME" || echo "无法获取附加策略"
    
    echo ""
    echo "内联策略:"
    aws iam list-user-policies --user-name "$USER_NAME" || echo "无法获取内联策略"
    
    echo ""
    echo "用户组:"
    aws iam get-groups-for-user --user-name "$USER_NAME" || echo "无法获取用户组"
    
elif [[ $USER_ARN == *":role/"* ]]; then
    ROLE_NAME=$(echo "$USER_ARN" | cut -d'/' -f2)
    echo "Role Name: $ROLE_NAME"
    echo "当前使用的是IAM角色，而不是用户"
    
    echo ""
    echo "3. 检查角色权限..."
    aws iam list-attached-role-policies --role-name "$ROLE_NAME" || echo "无法获取角色策略"
    
else
    echo "未知的身份类型"
fi

echo ""
echo "4. 测试关键权限..."

# 测试EKS权限
if aws eks list-clusters --region ${AWS_REGION:-us-west-2} > /dev/null 2>&1; then
    echo "✅ EKS权限正常"
else
    echo "❌ EKS权限不足"
fi

# 测试EC2权限
if aws ec2 describe-vpcs --region ${AWS_REGION:-us-west-2} > /dev/null 2>&1; then
    echo "✅ EC2权限正常"
else
    echo "❌ EC2权限不足"
fi

# 测试IAM权限
if aws iam list-roles --max-items 1 > /dev/null 2>&1; then
    echo "✅ IAM权限正常"
else
    echo "❌ IAM权限不足"
fi

echo ""
echo "检查完成！"