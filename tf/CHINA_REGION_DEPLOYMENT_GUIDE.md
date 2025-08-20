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

## ✅ 自动处理的功能

### 1. 数据库创建自动化

**功能**: 系统会根据区域自动选择合适的数据库创建方式

**实现方式**:
- **全球区域**: 使用 RDS Data API 自动创建数据库
- **中国区域**: 跳过自动创建，提供手动操作指导

**需要创建的数据库**:
- `dify_enterprise` - Dify 企业版主数据库
- `dify_audit` - 审计日志数据库
- `dify_plugin_daemon` - 插件守护进程数据库

## ⚠️ 中国区特殊要求

### 1. 手动数据库创建

**原因**: 中国区的 Aurora 数据库通常部署在私有子网中，本地无法直接访问

**解决方案**:
1. **完成基础设施部署**: `terraform apply`
2. **在 VPC 内创建 EC2 实例**: 用于访问 Aurora 数据库
3. **运行指导脚本**: `./china_region_database_setup_guide.sh`
4. **在 EC2 上执行数据库创建**: 使用 `create_dify_databases_china.sh`

### 2. 依赖工具要求

**中国区部署需要以下工具**:
- `psql` (PostgreSQL 客户端)
- `jq` (JSON 处理工具)
- `aws` CLI (已配置凭证)

**安装命令**:
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-client jq

# CentOS/RHEL
sudo yum install postgresql jq

# macOS
brew install postgresql jq
```

### 3. 网络连通性问题

**问题**: 
- Helm 仓库访问超时
- 容器镜像拉取失败
- 数据库连接失败

**自动解决方案**:
- RDS HTTP endpoint 自动禁用（中国区不支持）
- 数据库创建脚本自动选择（直连模式）

**手动解决方案**:
- 参考 `CHINA_REGION_NETWORK_SOLUTIONS.md` 获取详细解决方案
- 如果 Helm 仓库访问有问题，可以使用 `custom_helm_repositories` 配置备用仓库

### 3. 网络连通性验证

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

**注意**: 中国区部署完成后会显示数据库手动创建的指导信息。

### 3. 手动创建数据库（仅中国区）

```bash
# 运行指导脚本，获取详细操作步骤
./china_region_database_setup_guide.sh

# 按照指导在 VPC 内的 EC2 实例上执行数据库创建
# （需要先创建 EC2 实例并 SSH 连接）
./create_dify_databases_china.sh
```

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