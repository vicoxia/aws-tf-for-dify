# Dify 企业版 AWS 基础设施部署指南

本指南将帮助您在 AWS 上部署 Dify 企业版所需的基础设施。

## 重要说明

**此Terraform方案专门用于部署AWS基础设施，不包括Dify应用的部署。**

部署流程分为两个阶段：
1. **阶段一**：使用此Terraform方案部署AWS基础设施
2. **阶段二**：按照 `additional_docs` 目录下的部署文档手工部署Dify应用

## 架构概述

此部署方案包括以下AWS基础设施组件：

### AWS 基础设施
- **EKS 集群**: Kubernetes 控制平面和工作节点
- **Aurora PostgreSQL**: 主数据库服务
- **ElastiCache Redis**: 缓存和会话存储
- **OpenSearch**: 向量数据库服务
- **S3**: 文件存储
- **ECR**: 容器镜像仓库
- **VPC**: 网络隔离和安全

### Kubernetes 基础组件
- **AWS Load Balancer Controller**: ALB/NLB支持
- **NGINX Ingress Controller**: 流量路由（可选）
- **Cert-Manager**: SSL 证书管理（可选）
- **IRSA**: IAM角色和服务账户绑定
- **Monitoring Stack**: 可选的监控组件

## 前置要求

### 工具要求
- Terraform >= 1.0
- AWS CLI >= 2.0
- kubectl >= 1.24
- Helm >= 3.8

### AWS 权限要求
确保您的 AWS 凭证具有以下权限：
- EKS 集群管理
- EC2 实例和网络管理
- RDS 和 ElastiCache 管理
- S3 和 ECR 管理
- IAM 角色和策略管理

## 快速开始

### 1. 克隆仓库并配置

```bash
git clone <repository-url>
cd dify-aws-terraform
```

### 2. 配置 Terraform 变量

复制并编辑配置文件：

```bash
cp tf/terraform.tfvars.example tf/terraform.tfvars
```

编辑 `tf/terraform.tfvars` 文件，设置您的配置：

```hcl
# 基本配置
aws_region  = "us-west-2"
environment = "test"  # 或 "prod"

# 集群配置
cluster_name = "dify-eks-cluster"
cluster_version = "1.28"

# 节点配置
node_group_instance_types = ["t3.large"]
node_group_desired_size   = 2
node_group_max_size      = 4
node_group_min_size      = 1

# 数据库配置
db_instance_class = "db.r6g.large"
db_allocated_storage = 100
```

### 3. 部署基础设施

```bash
cd tf
terraform init
terraform plan
terraform apply
```

### 4. 配置 kubectl

```bash
aws eks update-kubeconfig --region us-west-2 --name dify-eks-cluster
```

### 5. 验证基础设施部署

```bash
kubectl get nodes
kubectl get namespaces
kubectl get serviceaccounts -n dify
```

### 6. 保存部署输出信息

Terraform部署完成后，请保存以下重要输出信息，在后续配置IRSA和部署Dify应用时会用到：

```
cluster_endpoint = "https://xxxxx.gr7.us-west-2.eks.amazonaws.com"
cluster_name = "dify-eks-cluster"
rds_endpoint = "dify-aurora-cluster.cluster-xxxxx.us-west-2.rds.amazonaws.com"
redis_endpoint = "dify-redis.xxxxx.cache.amazonaws.com"
opensearch_endpoint = "https://search-dify-opensearch-xxxxx.us-west-2.es.amazonaws.com"
s3_bucket_name = "dify-storage-xxxxx"
ecr_repository_url = "123456789012.dkr.ecr.us-west-2.amazonaws.com/dify"
```

## 后续步骤：部署Dify应用

基础设施部署完成后，请按照以下文档部署Dify应用：

### 测试环境部署
参考：`additional_docs/测试环境部署.md`

### 生产环境部署
参考：`additional_docs/生产环境部署.md`

这些文档将指导您：
1. 配置Helm仓库
2. 准备values.yaml配置文件
3. 配置数据库连接信息
4. 配置存储和向量数据库
5. 部署Dify应用

## 详细配置

### 环境配置

支持两种环境配置：

#### 测试环境 (`environment = "test"`)
- 较小的实例规格
- 基本配置
- 成本优化

#### 生产环境 (`environment = "prod"`)
- 高可用配置
- 更大的实例规格
- 完整监控

### 网络配置

#### 使用现有 VPC
```hcl
use_existing_vpc = true
vpc_id = "vpc-xxxxxxxxx"
private_subnet_ids = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
public_subnet_ids = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
```

#### 创建新 VPC
```hcl
use_existing_vpc = false
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
```

### 数据库配置

#### Aurora PostgreSQL
```hcl
db_instance_class = "db.r6g.large"
db_allocated_storage = 100
db_backup_retention_period = 7
db_backup_window = "03:00-04:00"
```

#### ElastiCache Redis
```hcl
redis_node_type = "cache.r6g.large"
redis_num_cache_nodes = 1
redis_parameter_group_name = "default.redis7"
```

### 存储配置

#### S3 存储桶
```hcl
s3_bucket_name = "dify-storage"
s3_versioning_enabled = true
```

#### ECR 仓库
```hcl
ecr_repository_name = "dify"
ecr_image_tag_mutability = "MUTABLE"
```

## 安全配置

### IRSA (IAM Roles for Service Accounts)

自动配置以下 IRSA 角色：
- `dify-api-role`: S3 和 ECR 访问权限
- `dify-plugin-build-role`: ECR 构建权限
- `dify-plugin-build-run-role`: 插件运行权限

### 网络安全

- 私有子网中的工作节点
- 安全组限制访问
- NACLs 网络访问控制

## 监控和日志

基础设施监控通过AWS原生服务提供：
- **CloudWatch**: 指标收集和告警
- **EKS控制平面日志**: Kubernetes审计和API日志
- **VPC Flow Logs**: 网络流量监控
- **RDS Performance Insights**: 数据库性能监控

## 维护和运维

### 备份策略

#### 数据库备份
- 自动快照：每日备份
- 保留期：7-30 天
- 跨区域复制（可选）

#### 应用数据备份
- S3 版本控制
- 生命周期策略
- 跨区域复制

### 更新和升级

#### 集群升级
```bash
# 更新 Terraform 配置
cluster_version = "1.29"

# 应用更新
terraform plan
terraform apply
```

### 扩缩容

#### 节点扩缩容
```hcl
node_group_desired_size = 5
node_group_max_size = 10
```

## 故障排除

### 常见问题

#### 1. 集群创建失败
- 检查 AWS 权限
- 验证 VPC 配置
- 查看 CloudFormation 事件

#### 2. 网络连接问题
- 检查安全组规则
- 验证路由表配置
- 测试 DNS 解析

### 日志查看

```bash
# 查看节点状态
kubectl describe nodes

# 查看事件
kubectl get events --sort-by='.lastTimestamp'

# 查看Terraform日志
export TF_LOG=DEBUG
terraform apply
```

## 成本优化

### 实例选择
- 使用 Spot 实例（非生产环境）
- 合适的实例规格
- 预留实例（生产环境）

### 存储优化
- S3 生命周期策略
- 数据压缩
- 冷存储迁移

## 清理资源

如需删除所有资源：

```bash
cd tf
terraform destroy
```

**警告**：此操作将删除所有AWS资源，包括数据库中的数据，请谨慎操作。

## 支持和社区

### 文档资源
- [AWS EKS 官方文档](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Dify 官方文档](https://docs.dify.ai/)

### 详细部署指南
- `tf/AWS_INFRASTRUCTURE_DEPLOYMENT_GUIDE.md` - 详细的基础设施部署指南
- `additional_docs/测试环境部署.md` - 测试环境Dify应用部署
- `additional_docs/生产环境部署.md` - 生产环境Dify应用部署

---

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。