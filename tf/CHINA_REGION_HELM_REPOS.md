# AWS 中国区部署配置指南

## 问题背景

AWS 中国区与全球区域存在以下差异：

### 1. 网络访问限制
无法直接访问海外的 Helm 仓库地址，如：
- `https://aws.github.io/eks-charts`
- `https://kubernetes.github.io/ingress-nginx`
- `https://charts.jetstack.io`

### 2. ARN 格式差异
中国区使用不同的 ARN 格式：
- **全球区域**: `arn:aws:service:region:account:resource`
- **中国区域**: `arn:aws-cn:service:region:account:resource`

## 自动解决方案

本 Terraform 配置已经实现了自动区域检测，当 `aws_region` 设置为中国区域时，会自动：

1. **使用中国区可访问的 Helm 镜像仓库**
2. **自动调整 ARN 格式**为 `arn:aws-cn:...`

### 支持的中国区域
- `cn-north-1` (北京)
- `cn-northwest-1` (宁夏)

### 自动配置内容

当检测到中国区域时，系统会自动进行以下配置：

#### Helm 仓库配置
| 组件 | 仓库地址 | 中国区访问性 |
|------|---------|-------------|
| AWS Load Balancer Controller | `https://aws.github.io/eks-charts` | ⚠️ 可能需要代理 |
| NGINX Ingress Controller | `https://kubernetes.github.io/ingress-nginx` | ✅ 通常可访问 |
| Cert-Manager | `https://charts.jetstack.io` | ✅ 通常可访问 |

**注意**: 当前配置对所有区域使用相同的官方仓库，因为：
1. 大多数官方仓库在中国区是可访问的
2. 专门的中国区镜像仓库可能不包含最新的 AWS 特定 Charts

#### ARN 格式调整
| 服务 | 全球区域格式 | 中国区域格式 |
|------|-------------|-------------|
| IAM 策略 | `arn:aws:iam::aws:policy/...` | `arn:aws-cn:iam::aws:policy/...` |
| OpenSearch | `arn:aws:es:region:account:domain/...` | `arn:aws-cn:es:region:account:domain/...` |

## 中国区 Helm 仓库选项

### 1. 官方仓库（推荐）
大多数情况下，官方仓库在中国区是可访问的：
- `https://aws.github.io/eks-charts` - AWS Load Balancer Controller
- `https://kubernetes.github.io/ingress-nginx` - NGINX Ingress
- `https://charts.jetstack.io` - Cert-Manager

### 2. 备用镜像仓库
如果官方仓库不可访问，可以尝试：

#### Azure 中国镜像
```
https://mirror.azure.cn/kubernetes/charts/
```
⚠️ 注意：此仓库主要包含旧版本的 Kubernetes Charts，可能不包含 AWS Load Balancer Controller

#### 华为云镜像
```
https://mirrors.huaweicloud.com/repository/chartrepo/public/
```

### 3. 替代方案
如果 AWS Load Balancer Controller 无法安装：
- 使用 NGINX Ingress Controller 替代
- 手动下载并部署 YAML 文件
- 使用 Kubernetes 原生的 Service LoadBalancer

## 自定义仓库配置

如果需要使用其他仓库地址，可以在 `terraform.tfvars` 中配置：

```hcl
custom_helm_repositories = {
  aws_load_balancer_controller = "https://your-custom-repo.com/charts"
  nginx_ingress               = "https://your-custom-repo.com/charts"  
  cert_manager               = "https://your-custom-repo.com/charts"
}
```

## 注意事项

1. **Chart 版本兼容性**：镜像仓库中的 Chart 版本可能与官方仓库不完全同步，建议验证所需版本是否可用。

2. **Chart 名称**：某些镜像仓库中的 Chart 名称可能与官方不同，如遇到问题请检查具体的 Chart 名称。

3. **网络连通性**：部署前建议先测试仓库的网络连通性：
   ```bash
   curl -I https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
   ```

4. **私有仓库**：如果使用私有 Harbor 或其他仓库，可能需要配置认证信息。

## 验证配置

部署前可以使用以下命令验证 Helm 仓库配置：

```bash
# 添加仓库
helm repo add test-repo https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts

# 更新仓库索引
helm repo update

# 搜索所需的 Chart
helm search repo aws-load-balancer-controller
helm search repo ingress-nginx
helm search repo cert-manager
```

## 故障排除

如果遇到 Helm 安装失败，请检查：

1. 网络连通性
2. Chart 名称和版本
3. 仓库认证配置
4. Kubernetes 集群状态

建议在中国区部署时，优先使用阿里云或华为云的镜像仓库，它们通常有较好的网络连通性和更新频率。