# Dify 企业版 AWS 基础设施部署

本仓库包含在AWS上部署Dify企业版所需基础设施的Terraform配置。

## 🚀 重要说明

**此Terraform方案专门用于部署AWS基础设施，不包括Dify应用的部署。**

部署流程分为三个阶段：
1. **阶段一**：使用此Terraform方案部署AWS基础设施
2. **阶段二**：验证基础设施部署并生成Dify部署配置
3. **阶段三**：使用生成的配置部署Dify应用

## 🏗️ 部署的AWS基础设施

### 核心服务
- **EKS集群**: Kubernetes 1.33，使用Graviton3处理器（ARM64）
- **Aurora PostgreSQL Serverless v2**: 主数据库服务，自动扩缩容
- **ElastiCache Redis**: 缓存和会话存储（Cluster Mode Disabled）
- **OpenSearch**: 向量数据库服务
- **S3存储桶**: 文件存储，支持版本控制
- **ECR仓库**: 容器镜像存储

### 网络和安全
- **VPC**: 网络隔离和安全，自动获取可用区
- **子网**: 公有和私有子网，多可用区部署
- **NAT Gateway**: 单个NAT Gateway（成本优化）
- **安全组**: 网络访问控制
- **IAM角色**: 为IRSA提供权限策略

### Kubernetes基础组件
- **Dify命名空间**: 应用部署的专用命名空间
- **IRSA ServiceAccounts**: 为Dify应用提供AWS权限的服务账户

### 可选组件（通过变量控制）
- **AWS Load Balancer Controller**: ALB/NLB支持
- **NGINX Ingress Controller**: 流量路由
- **Cert-Manager**: SSL证书管理

## 📊 环境特定配置

### 测试环境 (`environment = "test"`)
- **EKS节点**: 1个节点，m7g.xlarge (4 vCPU, 16 GB RAM, Graviton3)
- **Aurora**: 0.5-4 ACU，成本优化
- **Redis**: 单节点模式，cache.t4g.micro
- **OpenSearch**: t3.small.search，单实例

### 生产环境 (`environment = "prod"`)  
- **EKS节点**: 6个节点，m7g.2xlarge (8 vCPU, 32 GB RAM, Graviton3)
- **Aurora**: 1-8 ACU，高可用配置
- **Redis**: 主从复制模式，自动故障转移
- **OpenSearch**: 多实例，高可用部署

## 🔧 完整部署流程

### 阶段一：部署AWS基础设施

```bash
# 1. 克隆仓库
git clone <repository-url>
cd dify-aws-terraform

# 2. 配置变量
cp tf/terraform.tfvars.example tf/terraform.tfvars
# 编辑 terraform.tfvars 文件，设置：
# - environment = "test" 或 "prod"
# - aws_region = "your-region"
# - aws_account_id = "your-account-id"

# 3. 部署基础设施
cd tf
terraform init
terraform plan
terraform apply -auto-approve
```

### 阶段二：验证部署并生成配置

```bash
# 1. 快速验证基础设施状态
./quick_verify.sh

# 2. 完整验证（推荐）
./verify_deployment.sh

# 3. 生成Dify部署配置
./post_apply.sh
```

**验证脚本功能:**
- ✅ **快速验证**: 检查7个核心资源状态（30秒内完成）
- ✅ **完整验证**: 全面检查所有AWS资源、Kubernetes集群、Helm部署
- ✅ **自动报告**: 生成详细验证报告和故障排除建议

**配置生成功能:**
- 📋 **out.log**: 包含所有Terraform输出和敏感信息
- ⚙️ **dify_values_*.yaml**: 可直接使用的Helm Values配置
- 🚀 **deploy_dify_*.sh**: 一键部署脚本
- 📝 **dify_deployment_config_*.txt**: 详细环境变量配置

### 阶段三：部署Dify应用

#### 方式A: 使用自动生成的部署脚本（推荐）
```bash
# 1. 修改域名和密钥（必需）
sed -i 's/dify.local/your-domain.com/g' dify_values_*.yaml
sed -i 's/dify123456/your-secure-key/g' dify_values_*.yaml

# 2. 运行自动部署脚本
./deploy_dify_*.sh
```

#### 方式B: 手动部署
```bash
# 1. 更新kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# 2. 添加Helm仓库
helm repo add dify https://langgenius.github.io/dify-helm
helm repo update

# 3. 部署应用
helm upgrade -i dify -f dify_values_*.yaml dify/dify -n dify

# 4. 验证部署
kubectl get pods -n dify
kubectl get svc -n dify
kubectl get ingress -n dify
```

## 🔍 验证和故障排除

### 基础设施验证

#### 快速验证输出示例
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

#### 完整验证功能
- 🔍 **VPC和网络**: 子网、NAT Gateway、路由表
- 🔍 **EKS集群**: 集群状态、节点健康、系统Pod
- 🔍 **数据库服务**: Aurora、Redis、OpenSearch连接性
- 🔍 **存储服务**: S3权限、ECR访问
- 🔍 **Kubernetes**: 命名空间、ServiceAccount、IRSA配置
- 🔍 **Helm部署**: AWS Load Balancer Controller、Cert-Manager状态

### 常见问题解决

#### 1. 权限问题
```bash
# 检查AWS凭证
aws sts get-caller-identity

# 检查EKS访问
aws eks describe-cluster --name <cluster-name>
```

#### 2. 网络连接问题
```bash
# 更新kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# 测试连接
kubectl get nodes
```

#### 3. Terraform状态问题
```bash
# 检查状态
terraform show

# 刷新状态
terraform refresh
```

## 📝 生成的配置文件

### Helm Values配置示例
```yaml
global:
  appSecretKey: 'your-secure-key'
  consoleApiDomain: "console.your-domain.com"
  serviceApiDomain: "api.your-domain.com"

persistence:
  type: "s3"
  s3:
    endpoint: "https://s3.us-east-1.amazonaws.com"
    region: "us-east-1"
    bucketName: "your-s3-bucket"
    useAwsManagedIam: true  # 使用IRSA

externalPostgres:
  enabled: true
  address: "your-aurora-endpoint"
  credentials:
    dify:
      database: "dify"
      username: "postgres"
      password: "your-secure-password"

externalRedis:
  enabled: true
  host: "your-redis-endpoint"
  port: 6379
```

### 环境变量配置示例
```bash
# 基础信息
ENVIRONMENT=test
AWS_REGION=us-east-1
CLUSTER_NAME=dify-eks-cluster

# 数据库信息（包含敏感信息）
RDS_ENDPOINT=your-aurora-endpoint
RDS_PASSWORD=your-secure-password
REDIS_ENDPOINT=your-redis-endpoint
OPENSEARCH_ENDPOINT=your-opensearch-endpoint
```

## 🔐 安全特性

### IRSA集成
- 无需在Pod中存储AWS凭证
- 细粒度权限控制
- 自动ServiceAccount配置

### 网络安全
- 私有子网部署
- 安全组控制
- VPC网络隔离

### 数据加密
- S3存储加密
- RDS数据加密
- 传输中加密

## 💰 成本优化

### 测试环境优化
- 单个NAT Gateway（节省67%成本）
- Graviton3处理器（节省20%成本）
- Aurora Serverless v2（按需付费）
- 单节点Redis（最小配置）

### 生产环境配置
- 高可用多节点部署
- 自动扩缩容
- 预留实例优化

## 🔄 维护和更新

### 配置更新
```bash
# 重新生成配置
./generate_dify_config.sh

# 更新Helm部署
helm upgrade dify -f dify_values_*.yaml dify/dify -n dify
```

### 基础设施更新
```bash
# 更新Terraform配置
terraform plan
terraform apply

# 重新验证
./verify_deployment.sh
```

## 🗑️ 资源清理

```bash
# 删除Dify应用
helm uninstall dify -n dify

# 删除基础设施
cd tf
terraform destroy
```

⚠️ **警告**: 此操作将永久删除所有数据，请先备份重要信息。

## 🔒 安全注意事项

### 敏感文件管理
- 生成的配置文件包含密码和密钥
- 文件权限自动设置为600
- 不要提交敏感文件到版本控制

### 密钥轮换
```bash
# 定期更换数据库密码
# 更新API密钥和应用密钥
# 轮换IRSA角色权限
```

### 域名配置
```bash
# 修改所有默认域名
consoleApiDomain: "console.your-company.com"
serviceApiDomain: "api.your-company.com"
appApiDomain: "app.your-company.com"
```

## 📚 脚本和工具

### 验证脚本
- `quick_verify.sh` - 快速验证核心资源
- `verify_deployment.sh` - 完整验证所有资源

### 配置生成脚本
- `generate_dify_config.sh` - 完整配置生成器
- `post_apply.sh` - Terraform后置处理脚本

### 部署脚本
- `deploy_dify_*.sh` - 自动生成的部署脚本

## 📖 参考文档

- [Dify企业版官方文档](https://enterprise-docs.dify.ai/)
- [Helm Chart配置](https://langgenius.github.io/dify-helm/)
- [AWS EKS文档](https://docs.aws.amazon.com/eks/)
- [Kubernetes IRSA配置](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目。

## 🆘 支持

如遇到问题，请：
1. 运行验证脚本检查资源状态
2. 查看生成的验证报告
3. 检查CloudWatch日志
4. 在GitHub上创建Issue并提供详细信息

## 📄 许可证

本项目采用MIT许可证。详见[LICENSE](LICENSE)文件。


