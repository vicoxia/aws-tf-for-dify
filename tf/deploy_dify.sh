#!/bin/bash

# Dify应用快速部署脚本

echo "🚀 开始部署Dify企业版应用"
echo "=========================="

# 检查必需文件
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars文件不存在"
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "❌ .env文件不存在"
    exit 1
fi

# 加载环境变量
echo "📋 加载环境变量..."
source .env

# 验证配置
echo "🔍 验证配置..."
if [ -f "validate_config.sh" ]; then
    ./validate_config.sh
    if [ $? -ne 0 ]; then
        echo "❌ 配置验证失败"
        exit 1
    fi
else
    echo "⚠️  validate_config.sh不存在，跳过验证"
fi

# 检查terraform状态
echo "🔧 检查Terraform状态..."
if [ ! -f "terraform.tfstate" ]; then
    echo "❌ Terraform状态文件不存在，请先运行 terraform init"
    exit 1
fi

# 检查是否已有dify helm release
if terraform state list | grep -q "helm_release.dify"; then
    echo "✅ Dify Helm release已存在于Terraform状态中"
    echo "🔄 将更新现有部署..."
else
    echo "📦 将创建新的Dify部署..."
fi

# 生成部署计划
echo "📋 生成部署计划..."
terraform plan -out=dify-deploy.tfplan

if [ $? -ne 0 ]; then
    echo "❌ Terraform plan失败"
    exit 1
fi

# 询问用户确认
echo ""
echo "🤔 是否继续部署？(y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "❌ 部署已取消"
    exit 0
fi

# 执行部署
echo "🚀 开始部署..."
terraform apply dify-deploy.tfplan

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 部署完成！"
    echo ""
    echo "📊 检查部署状态..."
    
    # 等待一段时间让资源创建
    echo "⏳ 等待30秒让资源初始化..."
    sleep 30
    
    # 检查Helm release
    echo "🔍 检查Helm releases..."
    helm list -n dify
    
    echo ""
    echo "🔍 检查Pod状态..."
    kubectl get pods -n dify
    
    echo ""
    echo "🔍 检查服务状态..."
    kubectl get services -n dify
    
    echo ""
    echo "📋 下一步操作："
    echo "1. 等待所有Pod变为Running状态"
    echo "2. 配置域名DNS指向LoadBalancer"
    echo "3. 访问应用: https://$(grep dify_hostname terraform.tfvars | cut -d'"' -f2)"
    
else
    echo "❌ 部署失败"
    echo "🔍 检查错误信息并重试"
    exit 1
fi