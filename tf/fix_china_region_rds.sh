#!/bin/bash

echo "=== 修复中国区 RDS HTTP Endpoint 问题 ==="

# 检查当前区域设置
echo "1. 检查当前配置..."
if [ -f "terraform.tfvars" ]; then
    REGION=$(grep "aws_region" terraform.tfvars | cut -d'"' -f2)
    echo "   当前区域: $REGION"
else
    echo "   未找到 terraform.tfvars 文件"
    echo "   请确保设置了正确的 aws_region"
fi

# 检查是否为中国区
if [[ "$REGION" == "cn-north-1" || "$REGION" == "cn-northwest-1" ]]; then
    echo "   ✅ 检测到中国区域: $REGION"
    echo "   RDS HTTP Endpoint 应该被禁用"
else
    echo "   ℹ️  非中国区域: $REGION"
    echo "   RDS HTTP Endpoint 应该被启用"
fi

echo ""
echo "2. 检查 Terraform 状态..."

# 检查 RDS 集群状态
if terraform state list | grep -q "aws_rds_cluster.main"; then
    echo "   ✅ 找到 RDS 集群资源"
    
    # 获取当前的 enable_http_endpoint 设置
    HTTP_ENDPOINT=$(terraform state show aws_rds_cluster.main | grep "enable_http_endpoint" | awk '{print $3}')
    echo "   当前 HTTP Endpoint 设置: $HTTP_ENDPOINT"
    
    if [[ "$REGION" == "cn-north-1" || "$REGION" == "cn-northwest-1" ]]; then
        if [ "$HTTP_ENDPOINT" = "true" ]; then
            echo "   ❌ 中国区域但 HTTP Endpoint 仍为 true，需要修复"
            echo ""
            echo "3. 执行修复操作..."
            echo "   正在标记 RDS 集群资源为 tainted..."
            terraform taint aws_rds_cluster.main
            echo "   ✅ 资源已标记，下次 apply 时将重新创建"
        else
            echo "   ✅ 配置正确"
        fi
    fi
else
    echo "   ℹ️  未找到 RDS 集群资源，可能尚未创建"
fi

echo ""
echo "4. 建议的操作步骤："
echo "   1. 确认 terraform.tfvars 中 aws_region 设置正确"
echo "   2. 运行 terraform plan 检查配置"
echo "   3. 运行 terraform apply 应用更改"
echo ""
echo "如果问题仍然存在，请手动执行："
echo "   terraform taint aws_rds_cluster.main"
echo "   terraform apply"