# Dify Enterprise AWS 部署指南

本项目使用 Terraform 在 AWS 上部署 Dify Enterprise 环境，支持测试环境和生产环境的自动化部署。

## 架构概述

### 测试环境配置
- **EKS 集群**: 1个工作节点 (m7g.xlarge - 4核CPU, 16GB内存, Graviton芯片)
- **Aurora PostgreSQL 无服务器 v2**: 0.5-4 ACU (Aurora容量单位)，自动扩缩容
- **ElastiCache Redis**: cache.t4g.micro (1GB内存)
- **OpenSearch**: m6g.large.search (4核CPU, 8GB内存, 100GB存储)
- **S3存储**: 100GB

### 生产环境配置
- **EKS 集群**: 6个工作节点 (m7g.2xlarge - 8核CPU, 32GB内存, Graviton芯片)
- **Aurora PostgreSQL 无服务器 v2**: 1-8 ACU (Aurora容量单位)，自动扩缩容
- **ElastiCache Redis**: cache.t4g.small (2GB内存)
- **OpenSearch**: 3台 m6g.4xlarge.search (16核CPU, 64GB内存, 100GB存储)
- **S3存储**: 512GB

### Aurora 无服务器 v2 的优势

Aurora 无服务器 v2 相比传统的 RDS PostgreSQL 实例具有以下优势：

1. **自动扩展**：根据工作负载自动调整容量，从最小容量到最大容量，无需手动干预
2. **成本效益**：只为实际使用的资源付费，而不是为预置的固定资源付费
3. **高可用性**：Aurora 提供内置的高可用性和故障转移功能，跨可用区复制
4. **兼容 PostgreSQL**：完全兼容 PostgreSQL，无需更改应用程序代码
5. **零停机时间扩展**：无需手动调整实例大小，避免了传统实例扩展时的停机时间
6. **读写分离**：提供独立的读取器端点，便于实现读写分离，提高性能

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

### 3. 部署基础设施

```bash
# 查看部署计划
terraform plan

# 执行部署
terraform apply
？？terraform apply -parallelism=20 （使用 -parallelism=n 参数来调整并发数量（默认值为 10）
```

### 4. 配置 kubectl

```bash
# 更新 kubeconfig
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# 验证连接
kubectl get nodes
```

## 区域特殊配置

### AWS 中国区域

如果部署在 AWS 中国区域，需要额外配置：

在 `terraform.tfvars` 中配置 EKS Chart 仓库：
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

### 1. EKS 节点无法加入集群
- 检查子网路由表配置
- 验证安全组规则
- 确认 IAM 角色权限

### 2. Aurora 数据库连接问题
- 检查安全组配置
- 验证子网组设置
- 确认数据库凭证
- 区分写入端点和读取端点的使用场景

### 3. OpenSearch 访问问题
- 检查 VPC 配置
- 验证安全组规则
- 确认访问策略

## 安全最佳实践

1. **网络隔离**: 所有数据库和缓存服务部署在私有子网
2. **加密**: 启用静态加密和传输加密
3. **访问控制**: 使用 IAM 角色和安全组限制访问
4. **密码管理**: 使用 AWS Secrets Manager 管理敏感信息
5. **监控**: 启用 CloudTrail 和 CloudWatch 监控

## 远程执行 Terraform 命令

在远程EC2实例上执行Terraform命令时，如果SSH连接中断，命令执行也会被中断。以下是几种解决方案，确保即使SSH连接断开，Terraform命令也能继续执行，并且重新连接后可以查看执行结果。

### 方案一：使用 Screen（推荐）

Screen是一个终端复用器，允许你在一个终端会话中打开多个窗口，并且在断开连接后保持会话运行。

```bash
# 安装screen
sudo yum install screen -y   # Amazon Linux/CentOS
# 或
sudo apt-get install screen -y   # Ubuntu/Debian

# 创建新的screen会话
screen -S terraform

# 在screen会话中执行terraform命令
terraform apply

# 分离screen会话（不终止会话）
# 按 Ctrl+A 然后按 D

# 重新连接到screen会话
screen -r terraform

# 列出所有screen会话
screen -ls

# 终止screen会话
exit  # 或按 Ctrl+D
```

### 方案二：使用 Tmux

Tmux是Screen的现代替代品，提供类似的功能但有更多的特性。

```bash
# 安装tmux
sudo yum install tmux -y   # Amazon Linux/CentOS
# 或
sudo apt-get install tmux -y   # Ubuntu/Debian

# 创建新的tmux会话
tmux new -s terraform

# 在tmux会话中执行terraform命令
terraform apply

# 分离tmux会话（不终止会话）
# 按 Ctrl+B 然后按 D

# 重新连接到tmux会话
tmux attach -t terraform

# 列出所有tmux会话
tmux ls

# 终止tmux会话
exit  # 或按 Ctrl+D
```

### 方案三：使用 nohup 命令

如果不想使用终端复用器，可以使用nohup命令，它会忽略SIGHUP信号（当终端关闭时发送的信号）。

```bash
# 使用nohup执行terraform命令，并将输出重定向到文件
nohup terraform apply > terraform.log 2>&1 &

# 查看进程
ps aux | grep terraform

# 查看输出日志
tail -f terraform.log
```

### 方案四：使用 systemd 服务

对于需要定期执行的Terraform任务，可以创建systemd服务。

```bash
# 创建systemd服务文件
sudo nano /etc/systemd/system/terraform-apply.service

# 服务文件内容
[Unit]
Description=Terraform Apply Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/path/to/terraform/project
ExecStart=/usr/bin/terraform apply -auto-approve
StandardOutput=file:/path/to/terraform.log
StandardError=file:/path/to/terraform-error.log

[Install]
WantedBy=multi-user.target

# 重新加载systemd配置
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start terraform-apply

# 查看服务状态
sudo systemctl status terraform-apply

# 查看日志
sudo journalctl -u terraform-apply
```

### 最佳实践

1. **使用终端复用器**：对于交互式操作，推荐使用Screen或Tmux
2. **使用日志文件**：始终将输出重定向到日志文件，便于后续查看
3. **设置超时时间**：对于长时间运行的任务，考虑设置更长的SSH超时时间
4. **使用自动确认**：对于无人值守的操作，使用`-auto-approve`参数

## 支持

如遇问题，请检查：
1. AWS 凭证和权限配置
2. Terraform 版本兼容性
3. 区域可用性和配额限制
4. 网络配置和安全组规则
