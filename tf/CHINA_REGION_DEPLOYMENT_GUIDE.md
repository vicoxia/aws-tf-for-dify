# AWS 中国区部署指南

## 自动适配功能

本 Terraform 配置已实现中国区自动适配：

### ✅ 已自动处理的配置

1. **IAM 策略 ARN 格式**
   - 全球区域: `arn:aws:iam::aws:policy/...`
   - 中国区域: `arn:aws-cn:iam::aws:policy/...`

2. **服务 ARN 格式**
   - EC2: `arn:aws-cn:ec2:...`
   - ELB: `arn:aws-cn:elasticloadbalancing:...`
   - S3: `arn:aws-cn:s3:...`
   - OpenSearch: `arn:aws-cn:es:...`

3. **区域检测**
   - 自动检测 `cn-north-1` 和 `cn-northwest-1`
   - 无需手动配置

## ⚠️ 需要手动处理的问题

### 1. RDS Data API 不可用

**问题**: 中国区不支持 RDS Data API，无法自动创建数据库

**解决方案**: 
- 参考 `create_dify_databases_china.md` 手动创建数据库
- 需要创建的数据库：
  - `dify_enterprise`
  - `dify_audit`
  - `dify_plugin_daemon`

### 2. 网络连通性验证

**建议操作**:
```bash
# 验证 Helm 仓库访问
curl -I https://aws.github.io/eks-charts

# 验证 ECR Public 访问
curl -I https://public.ecr.aws

# 验证 GitHub 访问
curl -I https://kubernetes.github.io/ingress-nginx
```

## 部署步骤

### 1. 配置 terraform.tfvars

```hcl
# 设置中国区域
aws_region = "cn-northwest-1"  # 或 cn-north-1
aws_account_id = "your-account-id"

# 其他配置保持不变
environment = "test"
```

### 2. 执行 Terraform 部署

```bash
terraform init
terraform plan
terraform apply
```

### 3. 手动创建数据库

部署完成后，按照 `create_dify_databases_china.md` 的指导手动创建数据库。

### 4. 验证部署

```bash
# 检查 EKS 集群
aws eks describe-cluster --name dify-eks-cluster --region cn-northwest-1

# 检查 RDS 集群
aws rds describe-db-clusters --region cn-northwest-1

# 检查 Helm 部署
kubectl get pods -n kube-system
kubectl get pods -n dify
```

## 故障排除

### IAM 策略错误

如果遇到 "Partition 'aws' is not valid" 错误：
- 检查 `locals.tf` 中的区域检测逻辑
- 确认 `aws_region` 变量设置正确

### 网络连接问题

如果 Helm 安装失败：
- 检查网络连通性
- 考虑使用企业代理
- 使用 `custom_helm_repositories` 变量指定备用仓库

### RDS 连接问题

如果无法连接 RDS：
- 检查安全组配置
- 确认子网路由配置
- 验证 VPC 网络设置

## 验证清单

部署完成后，请验证以下项目：

- [ ] EKS 集群运行正常
- [ ] RDS Aurora 集群可访问
- [ ] ElastiCache Redis 可访问
- [ ] OpenSearch 域可访问
- [ ] S3 存储桶已创建
- [ ] ECR 仓库已创建
- [ ] IAM 角色和策略正确
- [ ] Helm Charts 部署成功
- [ ] 数据库已手动创建
- [ ] 网络连通性正常

## 支持的中国区域

- `cn-north-1` (北京)
- `cn-northwest-1` (宁夏)

其他区域将使用全球区域的配置格式。