# Dify企业版AWS基础设施验证脚本

本目录包含两个验证脚本，用于在Terraform部署完成后验证所有AWS资源是否正确创建。

## 脚本说明

### 1. `verify_deployment.sh` - 完整验证脚本

**功能特点:**
- 全面验证所有AWS资源状态
- 检查Kubernetes集群健康状况
- 验证Helm部署状态
- 生成详细的验证报告
- 提供故障排除建议

**验证内容:**
- ✅ VPC和网络资源（子网、NAT Gateway等）
- ✅ EKS集群和节点组状态
- ✅ Aurora PostgreSQL Serverless v2
- ✅ ElastiCache Redis（Cluster Mode Disabled）
- ✅ OpenSearch域
- ✅ S3存储桶和权限
- ✅ ECR容器仓库
- ✅ Helm部署（AWS Load Balancer Controller、Cert-Manager）
- ✅ Kubernetes资源（命名空间、ServiceAccount等）

### 2. `quick_verify.sh` - 快速验证脚本

**功能特点:**
- 快速检查核心资源状态
- 简洁的输出格式
- 适合CI/CD流水线使用

**验证内容:**
- ✅ EKS集群状态
- ✅ 节点组状态
- ✅ Aurora数据库状态
- ✅ Redis缓存状态
- ✅ OpenSearch状态
- ✅ S3存储桶可访问性
- ✅ ECR仓库可访问性

## 使用方法

### 前置条件

确保已安装以下工具：
```bash
# 必需工具
aws --version      # AWS CLI
kubectl version    # Kubernetes CLI
terraform version  # Terraform
helm version       # Helm (仅完整验证需要)
```

确保AWS凭证已配置：
```bash
aws configure list
```

### 运行验证

#### 方式1: 完整验证（推荐）
```bash
cd tf
./verify_deployment.sh
```

#### 方式2: 快速验证
```bash
cd tf
./quick_verify.sh
```

### 输出示例

#### 快速验证输出
```
==========================================
  Dify基础设施快速验证
  集群: dify-eks-cluster
  区域: us-east-1
==========================================
EKS集群状态: ACTIVE
节点组状态: ACTIVE
Aurora数据库: AVAILABLE
Redis缓存: AVAILABLE
OpenSearch: AVAILABLE
S3存储桶: ACCESSIBLE
ECR仓库: ACCESSIBLE
==========================================
```

#### 完整验证输出
```
[INFO] 检查必要工具...
[SUCCESS] 所有必要工具已安装
[INFO] 获取Terraform输出...
[SUCCESS] 成功获取Terraform输出
[INFO] 验证VPC和网络资源...
[SUCCESS] VPC (vpc-12345678) 存在且可访问
[SUCCESS] 发现 6 个子网（公有+私有）
[SUCCESS] NAT Gateway 已创建并可用
...
```

## 故障排除

### 常见问题

#### 1. 权限错误
```bash
# 检查AWS凭证
aws sts get-caller-identity

# 检查权限
aws iam get-user
```

#### 2. 区域不匹配
```bash
# 检查当前区域
aws configure get region

# 或在脚本中指定区域
export AWS_DEFAULT_REGION=us-east-1
```

#### 3. Terraform状态文件问题
```bash
# 确保在正确目录运行
ls -la terraform.tfstate

# 检查Terraform状态
terraform show
```

#### 4. kubectl连接问题
```bash
# 更新kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# 测试连接
kubectl get nodes
```

### 验证失败处理

如果验证失败，请按以下步骤排查：

1. **检查Terraform状态**
   ```bash
   terraform plan
   terraform refresh
   ```

2. **检查AWS资源**
   ```bash
   aws eks describe-cluster --name <cluster-name>
   aws rds describe-db-clusters
   aws elasticache describe-replication-groups
   ```

3. **检查网络连接**
   ```bash
   ping aws.amazon.com
   nslookup <rds-endpoint>
   ```

4. **重新运行Terraform**
   ```bash
   terraform apply -auto-approve
   ```

## 验证报告

完整验证脚本会生成详细报告文件：
- 文件名格式：`deployment_verification_YYYYMMDD_HHMMSS.txt`
- 包含所有资源状态和下一步操作建议
- 建议保存此报告用于文档记录

## 下一步操作

验证通过后，可以继续以下步骤：

1. **配置kubectl访问**
   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster-name>
   ```

2. **验证集群连接**
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

3. **部署Dify应用**
   - 参考 `additional_docs/测试环境部署.md`
   - 参考 `additional_docs/生产环境部署.md`

4. **配置域名和SSL证书**
   - 配置DNS记录指向Load Balancer
   - 配置Cert-Manager自动证书申请

## 支持

如果遇到问题，请检查：
- AWS服务状态页面
- Terraform文档
- EKS故障排除指南
- 相关服务的CloudWatch日志

---

**注意**: 这些脚本仅验证基础设施资源，不包括Dify应用本身的部署验证。应用部署验证请参考官方文档。