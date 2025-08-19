#!/bin/bash

echo "=== 验证 ECR Public 访问性 ==="

# ECR Public 相关的端点
endpoints=(
    "https://public.ecr.aws"
    "https://gallery.ecr.aws"
)

echo "检查 ECR Public 端点连通性..."
for endpoint in "${endpoints[@]}"; do
    echo -n "检查 $endpoint ... "
    if curl -s --connect-timeout 10 -I "$endpoint" > /dev/null 2>&1; then
        echo "✅ 可访问"
    else
        echo "❌ 不可访问"
    fi
done

echo ""
echo "=== ECR Public 镜像仓库信息 ==="
echo "AWS Load Balancer Controller 镜像："
echo "  - 新版本: public.ecr.aws/eks/aws-load-balancer-controller:v2.6.2"
echo "  - 旧版本: public.ecr.aws/eks/aws-alb-ingress-controller:v2.4.7"
echo ""
echo "注意事项："
echo "1. ECR Public 在中国区的访问性可能受到网络限制"
echo "2. 建议在实际部署时测试镜像拉取"
echo "3. 可以考虑将镜像推送到中国区的 ECR 私有仓库"
echo ""

# 检查是否可以访问 ECR Public Gallery
echo "检查 ECR Public Gallery..."
if curl -s --connect-timeout 10 https://gallery.ecr.aws > /dev/null 2>&1; then
    echo "✅ ECR Public Gallery 可访问"
    echo "可以在浏览器中访问: https://gallery.ecr.aws"
else
    echo "❌ ECR Public Gallery 不可访问"
fi

echo ""
echo "=== 中国区替代方案 ==="
echo "如果 ECR Public 不可访问，可以考虑："
echo "1. 使用阿里云容器镜像服务 (ACR)"
echo "2. 使用华为云容器镜像服务 (SWR)"
echo "3. 将镜像推送到 AWS 中国区的 ECR 私有仓库"
echo "4. 使用本地 Harbor 等私有镜像仓库"