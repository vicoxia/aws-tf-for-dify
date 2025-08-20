# 中国区网络访问解决方案

## 问题概述

在 AWS 中国区部署时，可能遇到以下网络访问问题：

1. **Helm 仓库无法访问** - GitHub 托管的仓库连接超时
2. **容器镜像拉取失败** - Docker Hub 等海外镜像仓库访问受限
3. **RDS Data API 不可用** - 中国区不支持此功能

## 自动解决方案

### 1. Helm 仓库访问问题

如果遇到 Helm 仓库访问问题，可以通过以下方式解决：

```hcl
# 使用自定义仓库
custom_helm_repositories = {
  aws_load_balancer_controller = "https://your-mirror-repo.com/charts"
}
```

### 2. RDS Data API 自动禁用

```hcl
# 中国区自动禁用 HTTP endpoint
enable_http_endpoint = var.aws_region != "cn-north-1" && var.aws_region != "cn-northwest-1"
```

**如果遇到 "EnableHttpEndpoint is not available in this region" 错误**：

```bash
# 强制重新创建 RDS 集群
terraform taint aws_rds_cluster.main
terraform apply
```

## 手动解决方案

### 方案一：使用 NGINX Ingress Controller

如果需要 Ingress 功能，推荐使用 NGINX Ingress Controller：

```hcl
# terraform.tfvars
install_aws_load_balancer_controller = false
install_nginx_ingress = true
```

### 方案二：配置企业代理

如果企业有海外代理，可以配置环境变量：

```bash
export HTTP_PROXY=http://your-proxy:port
export HTTPS_PROXY=http://your-proxy:port
export NO_PROXY=localhost,127.0.0.1,.aliyuncs.com
```

### 方案三：使用本地 Helm Chart

下载 Chart 到本地：

```bash
# 下载 AWS Load Balancer Controller Chart
wget https://github.com/aws/eks-charts/archive/refs/heads/master.zip
unzip master.zip
```

然后在 Terraform 中使用本地路径：

```hcl
custom_helm_repositories = {
  aws_load_balancer_controller = "./eks-charts-master"
}
```

### 方案四：使用中国区镜像仓库

配置使用阿里云等镜像仓库：

```hcl
custom_helm_repositories = {
  nginx_ingress = "https://mirror.azure.cn/kubernetes/charts/"
  cert_manager = "https://mirror.azure.cn/kubernetes/charts/"
}
```

## 容器镜像解决方案

### 1. 使用阿里云容器镜像服务

```bash
# 配置 Docker 镜像加速器
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://registry.cn-hangzhou.aliyuncs.com"
  ]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 2. 推送镜像到中国区 ECR

```bash
# 拉取并推送镜像到中国区 ECR
docker pull public.ecr.aws/eks/aws-load-balancer-controller:v2.4.7
docker tag public.ecr.aws/eks/aws-load-balancer-controller:v2.4.7 \
  your-account.dkr.ecr.cn-northwest-1.amazonaws.com.cn/aws-load-balancer-controller:v2.4.7
docker push your-account.dkr.ecr.cn-northwest-1.amazonaws.com.cn/aws-load-balancer-controller:v2.4.7
```

## 验证网络连通性

使用以下脚本验证网络访问：

```bash
#!/bin/bash

echo "=== 网络连通性测试 ==="

urls=(
    "https://aws.github.io/eks-charts"
    "https://kubernetes.github.io/ingress-nginx"
    "https://charts.jetstack.io"
    "https://public.ecr.aws"
    "https://mirror.azure.cn/kubernetes/charts/"
)

for url in "${urls[@]}"; do
    echo -n "测试 $url ... "
    if curl -s --connect-timeout 10 -I "$url" > /dev/null 2>&1; then
        echo "✅ 可访问"
    else
        echo "❌ 不可访问"
    fi
done
```

## 推荐的中国区配置

```hcl
# terraform.tfvars for China regions
aws_region = "cn-northwest-1"

# 正常启用 AWS Load Balancer Controller
install_aws_load_balancer_controller = true

# 如果网络访问有问题，可以配置备用仓库
# custom_helm_repositories = {
#   aws_load_balancer_controller = "https://your-mirror-repo.com/charts"
# }

# 或者使用 NGINX Ingress 作为替代
# install_aws_load_balancer_controller = false
# install_nginx_ingress = true
```

## 故障排除

### Helm 安装超时

```bash
# 增加超时时间
helm install --timeout 20m0s ...
```

### DNS 解析问题

```bash
# 使用公共 DNS
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
```

### 证书问题

```bash
# 跳过 TLS 验证（仅测试环境）
helm repo add --insecure-skip-tls-verify ...
```

## 监控和日志

部署后监控网络相关问题：

```bash
# 检查 Pod 状态
kubectl get pods --all-namespaces | grep -E "(Error|CrashLoop|ImagePull)"

# 查看网络相关事件
kubectl get events --sort-by=.metadata.creationTimestamp | grep -i "pull\|network\|timeout"

# 检查 CoreDNS
kubectl logs -n kube-system -l k8s-app=kube-dns
```