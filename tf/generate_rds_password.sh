#!/bin/bash

# RDS密码生成脚本
# 生成符合AWS RDS要求的密码

echo "🔐 生成RDS兼容密码"
echo "=================="

# AWS RDS密码要求：
# - 长度：8-128字符
# - 可用字符：字母、数字和以下符号：! # $ % & * + - = ? ^ _ ` | ~
# - 不能包含：/ @ " 空格
# - 不能以斜杠(/)开头

generate_rds_password() {
    local length=${1:-24}  # 默认24位
    
    # 使用允许的字符集
    local charset="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&*+-=?^_\`|~"
    
    # 生成密码
    local password=""
    for i in $(seq 1 $length); do
        password+="${charset:$((RANDOM % ${#charset})):1}"
    done
    
    # 确保不以斜杠开头（虽然我们的字符集中没有斜杠）
    if [[ $password == /* ]]; then
        password="A${password:1}"
    fi
    
    echo "$password"
}

# 生成RDS密码
RDS_PASSWORD=$(generate_rds_password 24)
echo "生成的RDS密码: $RDS_PASSWORD"

# 生成OpenSearch密码
OPENSEARCH_PASSWORD=$(generate_rds_password 24)
echo "生成的OpenSearch密码: $OPENSEARCH_PASSWORD"

echo ""
echo "📋 使用方法："
echo "export TF_VAR_rds_password=\"$RDS_PASSWORD\""
echo "export TF_VAR_opensearch_password=\"$OPENSEARCH_PASSWORD\""

echo ""
echo "🔧 或者直接运行："
echo "source <(./generate_rds_password.sh | tail -2)"

echo ""
echo "✅ 这些密码符合AWS RDS的所有要求"