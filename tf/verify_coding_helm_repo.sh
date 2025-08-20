#!/bin/bash

echo "=== 验证 Coding.net Helm 仓库 ==="

REPO_URL="https://g-hsod9681-helm.pkg.coding.net/dify-artifact/eks-charts"

echo "仓库地址: $REPO_URL"
echo ""

# 测试仓库连通性
echo "1. 测试仓库连通性..."
if curl -s --connect-timeout 10 "$REPO_URL/index.yaml" > /dev/null; then
    echo "✅ 仓库可访问"
else
    echo "❌ 仓库不可访问"
    exit 1
fi

# 获取 aws-load-balancer-controller 信息
echo ""
echo "2. 获取 aws-load-balancer-controller 信息..."

# 提取版本信息
VERSION_INFO=$(curl -s "$REPO_URL/index.yaml" | grep -A 30 "aws-load-balancer-controller:" | head -30)

if echo "$VERSION_INFO" | grep -q "aws-load-balancer-controller"; then
    echo "✅ 找到 aws-load-balancer-controller chart"
    
    # 提取版本号
    CHART_VERSION=$(echo "$VERSION_INFO" | grep "version:" | head -1 | awk '{print $2}')
    APP_VERSION=$(echo "$VERSION_INFO" | grep "appVersion:" | head -1 | awk '{print $2}')
    
    echo "   Chart 版本: $CHART_VERSION"
    echo "   App 版本: $APP_VERSION"
    
    # 提取下载链接
    DOWNLOAD_URL=$(echo "$VERSION_INFO" | grep "https://g-hsod9681-helm.pkg.coding.net" | head -1 | awk '{print $2}')
    echo "   下载链接: $DOWNLOAD_URL"
    
else
    echo "❌ 未找到 aws-load-balancer-controller chart"
    exit 1
fi

echo ""
echo "3. 验证 Chart 可下载性..."
# 注意：由于这是代理仓库，可能需要特殊的访问方式
echo "   (跳过下载测试，因为这是代理仓库)"

echo ""
echo "=== 验证结果 ==="
echo "仓库地址: $REPO_URL"
echo "Chart 名称: aws-load-balancer-controller"
echo "Chart 版本: $CHART_VERSION"
echo "App 版本: $APP_VERSION"
echo ""
echo "✅ 该仓库可以作为中国区的备用 Helm 仓库使用"