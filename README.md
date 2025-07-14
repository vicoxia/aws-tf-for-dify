# Dify Enterprise AWS 部署指南

本项目使用 Terraform 在 AWS 上部署 Dify Enterprise 环境，支持测试环境和生产环境的自动化部署。

## 架构概述

### 测试环境配置
- **EKS 集群**: 1个工作节点 (m7g.xlarge - 4核CPU, 16GB内存, Graviton芯片)
- **RDS PostgreSQL**: db.t4g.medium (2核CPU, 4GB内存, 256GB存储)
- **ElastiCache Redis**: cache.t4g.micro (1GB内存)
- **OpenSearch**: m6g.large.search (4核CPU, 8GB内存, 100GB存储)
- **S3存储**: 100GB

### 生产环境配置
- **EKS 集群**: 6个工作节点 (m7g.2xlarge - 8核CPU, 32GB内存, Graviton芯片)
- **RDS PostgreSQL**: db.t4g.large (2核CPU, 8GB内存, 512GB存储)
- **ElastiCache Redis**: cache.t4g.small (2GB内存)
- **OpenSearch**: 3台 m6g.4xlarge.search (16核CPU, 64GB内存, 100GB存储)
- **S3存储**: 512GB

## 前提条件

### 1. 工具安装

#### AWS CLI
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 配置 AWS 凭证
aws configure
```

#### Terraform
```bash
# macOS
brew install terraform

# Amazon Linux
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform
```

#### kubectl
```bash
# macOS
brew install kubectl

# Amazon Linux
请参考：https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
```

### 2. AWS 权限配置

确保您的 AWS 用户具有以下服务的管理权限：
- EC2 (VPC, 子网, 安全组)
- EKS
- RDS
- ElastiCache
- OpenSearch
- S3
- IAM
- Secrets Manager

## 部署步骤

### 1. 克隆和配置

```bash
git clone <repository-url>
cd aws-tf-for-dify

# 复制配置文件
cp terraform.tfvars.example terraform.tfvars
cp .env.example .env
```

### 2. 配置变量

编辑 `terraform.tfvars` 文件：

```hcl
# 基本配置
environment    = "test"  # 或 "prod"
aws_region     = "us-west-2"
aws_account_id = "123456789012"

# OpenSearch 配置
opensearch_admin_name = "admin"
opensearch_password   = "YourSecurePassword123!"

# 如果使用现有 VPC，配置以下参数
vpc_id = "vpc-xxxxxxxxx"
eks_cluster_subnets  = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
eks_nodes_subnets    = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
redis_subnets        = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
rds_subnets          = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
opensearch_subnets   = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
```

### 3. 初始化 Terraform 状态管理

**重要**: 首次部署需要先创建状态管理资源

```bash
# 1. 临时禁用远程状态
mv backend.tf backend.tf.bak

# 2. 初始化项目
terraform init

# 3. 创建状态管理资源
terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_locks

# 4. 恢复远程状态配置
mv backend.tf.bak backend.tf

# 5. 重新初始化以启用远程状态
terraform init
# 当提示是否复制状态到远程时，输入 "yes"
```

### 4. 部署基础设施

```bash
# 查看部署计划
terraform plan

# 执行部署
terraform apply
```

### 5. 配置 kubectl

```bash
# 更新 kubeconfig
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# 验证连接
kubectl get nodes
```

## 区域特殊配置

### AWS 中国区域

如果部署在 AWS 中国区域，需要额外配置：

1. 修改 `backend.tf` 中的区域：
```hcl
terraform {
  backend "s3" {
    bucket         = "test-eks-cluster-terraform-state"
    key            = "dify-enterprise/terraform.tfstate"
    region         = "cn-north-1"  # 或 cn-northwest-1
    dynamodb_table = "test-eks-cluster-terraform-locks"
    encrypt        = true
  }
}
```

2. 在 `terraform.tfvars` 中配置 EKS Chart 仓库：
```hcl
aws_eks_chart_repo_url = "https://kubernetes-charts-incubator.storage.googleapis.com/"
```

### 现有 VPC 配置

如果使用现有 VPC，确保：

1. **公共子网** (用于 ALB):
   - 至少 2 个不同 AZ 的公共子网
   - 添加标签: `kubernetes.io/role/elb = 1`

2. **私有子网** (用于工作负载):
   - 至少 2 个不同 AZ 的私有子网
   - 能够访问互联网 (通过 NAT 网关)
   - 添加标签: `kubernetes.io/role/internal-elb = 1`

## 输出信息

部署完成后，Terraform 会输出重要的连接信息：

```bash
# 查看输出
terraform output

# 获取敏感信息
terraform output -json | jq '.rds_endpoint.value'
```

## 清理资源

```bash
# 删除所有资源
terraform destroy

# 确认删除时输入 "yes"
```

## 故障排除

### 1. 状态锁定问题
```bash
# 强制解锁
terraform force-unlock <LOCK_ID>
```

### 2. EKS 节点无法加入集群
- 检查子网路由表配置
- 验证安全组规则
- 确认 IAM 角色权限

### 3. RDS 连接问题
- 检查安全组配置
- 验证子网组设置
- 确认数据库凭证

### 4. OpenSearch 访问问题
- 检查 VPC 配置
- 验证安全组规则
- 确认访问策略

## 安全最佳实践

1. **网络隔离**: 所有数据库和缓存服务部署在私有子网
2. **加密**: 启用静态加密和传输加密
3. **访问控制**: 使用 IAM 角色和安全组限制访问
4. **密码管理**: 使用 AWS Secrets Manager 管理敏感信息
5. **监控**: 启用 CloudTrail 和 CloudWatch 监控

## 支持

如遇问题，请检查：
1. AWS 凭证和权限配置
2. Terraform 版本兼容性
3. 区域可用性和配额限制
4. 网络配置和安全组规则