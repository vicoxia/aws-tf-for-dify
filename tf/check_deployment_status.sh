#!/bin/bash

# 部署状态检查脚本

echo "🔍 Dify部署状态检查"
echo "==================="

# 检查kubectl连接
echo "1. 检查Kubernetes连接..."
if kubectl cluster-info > /dev/null 2>&1; then
    echo "✅ kubectl连接正常"
    CLUSTER_NAME=$(kubectl config current-context)
    echo "当前集群: $CLUSTER_NAME"
else
    echo "❌ kubectl无法连接到集群"
    echo "请运行: aws eks update-kubeconfig --region <region> --name <cluster-name>"
    exit 1
fi

echo ""
echo "2. 检查命名空间..."
if kubectl get namespace dify > /dev/null 2>&1; then
    echo "✅ dify命名空间存在"
else
    echo "❌ dify命名空间不存在"
    echo "创建命名空间: kubectl create namespace dify"
fi

echo ""
echo "3. 检查Helm releases..."
echo "所有命名空间的Helm releases:"
helm list --all-namespaces

echo ""
echo "dify命名空间的Helm releases:"
helm list -n dify

echo ""
echo "4. 检查Kubernetes资源..."
echo "dify命名空间中的Pods:"
kubectl get pods -n dify

echo ""
echo "dify命名空间中的Services:"
kubectl get services -n dify

echo ""
echo "dify命名空间中的Deployments:"
kubectl get deployments -n dify

echo ""
echo "5. 检查Terraform状态..."
if [ -f "terraform.tfstate" ]; then
    echo "✅ Terraform状态文件存在"
    
    # 检查Helm release资源
    if terraform state list | grep -q "helm_release"; then
        echo "✅ Terraform中存在Helm release资源"
        echo "Helm releases in Terraform state:"
        terraform state list | grep "helm_release"
    else
        echo "❌ Terraform中没有Helm release资源"
        echo "可能需要启用Helm部署: install_dify_chart = true"
    fi
else
    echo "❌ Terraform状态文件不存在"
    echo "请先运行: terraform init && terraform apply"
fi

echo ""
echo "6. 检查Terraform变量..."
if [ -f "terraform.tfvars" ]; then
    echo "✅ terraform.tfvars文件存在"
    if grep -q "install_dify_chart.*true" terraform.tfvars; then
        echo "✅ install_dify_chart已启用"
    else
        echo "⚠️  install_dify_chart可能未启用"
        echo "检查terraform.tfvars中的install_dify_chart设置"
    fi
else
    echo "❌ terraform.tfvars文件不存在"
fi

echo ""
echo "7. 检查Helm仓库..."
if helm repo list | grep -q "dify"; then
    echo "✅ Dify Helm仓库已添加"
else
    echo "❌ Dify Helm仓库未添加"
    echo "添加仓库: helm repo add dify https://charts.dify.ai"
fi

echo ""
echo "8. 建议的下一步操作..."

# 根据检查结果给出建议
if ! kubectl get namespace dify > /dev/null 2>&1; then
    echo "🔧 创建dify命名空间:"
    echo "   kubectl create namespace dify"
fi

if ! helm repo list | grep -q "dify"; then
    echo "🔧 添加Dify Helm仓库:"
    echo "   helm repo add dify https://charts.dify.ai"
    echo "   helm repo update"
fi

if [ ! -f "terraform.tfstate" ]; then
    echo "🔧 初始化并应用Terraform:"
    echo "   terraform init"
    echo "   terraform apply"
elif ! terraform state list | grep -q "helm_release"; then
    echo "🔧 启用Helm部署:"
    echo "   在terraform.tfvars中设置: install_dify_chart = true"
    echo "   然后运行: terraform apply"
fi

if helm list -n dify | grep -q "dify"; then
    echo "✅ Dify已部署，检查Pod状态"
else
    echo "🔧 如果Terraform已运行但Helm部署失败，检查:"
    echo "   terraform state show helm_release.dify"
    echo "   kubectl describe pods -n dify"
fi

echo ""
echo "检查完成！"