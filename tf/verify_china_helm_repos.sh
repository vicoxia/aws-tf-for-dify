#!/bin/bash

echo "=== 验证中国区 Helm 仓库可用性 ==="

# 常见的中国区镜像仓库列表
repos=(
    "https://mirror.azure.cn/kubernetes/charts/"
    "https://mirrors.huaweicloud.com/repository/chartrepo/public/"
    "https://kubernetes-charts.storage.googleapis.com/"
    "https://charts.bitnami.com/bitnami"
    "https://kubernetes.github.io/ingress-nginx"
    "https://charts.jetstack.io"
)

echo "检查仓库连通性..."
for repo in "${repos[@]}"; do
    echo -n "检查 $repo ... "
    if curl -s --connect-timeout 5 -I "$repo" > /dev/null 2>&1; then
        echo "✅ 可访问"
    else
        echo "❌ 不可访问"
    fi
done

echo ""
echo "=== AWS Load Balancer Controller 特殊说明 ==="
echo "AWS Load Balancer Controller 在中国区的部署选项："
echo ""
echo "1. 官方仓库（可能需要代理）："
echo "   https://aws.github.io/eks-charts"
echo ""
echo "2. 手动下载 Chart："
echo "   可以从 GitHub 下载 Chart 文件到本地"
echo ""
echo "3. 使用 ECR Public（如果可访问）："
echo "   public.ecr.aws/eks/aws-load-balancer-controller"
echo ""
echo "4. 中国区替代方案："
echo "   - 使用 NGINX Ingress Controller 替代"
echo "   - 手动部署 AWS Load Balancer Controller YAML"
echo ""

# 检查是否可以访问 AWS 官方仓库
echo "检查 AWS 官方仓库..."
if curl -s --connect-timeout 10 https://aws.github.io/eks-charts/ > /dev/null 2>&1; then
    echo "✅ AWS 官方 eks-charts 仓库可访问"
    echo "可以尝试直接使用: https://aws.github.io/eks-charts"
else
    echo "❌ AWS 官方 eks-charts 仓库不可访问"
    echo "建议使用替代方案"
fi