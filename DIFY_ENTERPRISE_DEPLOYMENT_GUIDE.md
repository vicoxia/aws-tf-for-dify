# Dify 企业版完整部署指南

## 📋 目录

1. [概述](#概述)
2. [架构说明](#架构说明)
3. [前置要求](#前置要求)
4. [工具安装与配置](#工具安装与配置)
5. [AWS服务配置](#aws服务配置)
6. [Terraform部署](#terraform部署)
7. [Dify企业版部署](#dify企业版部署)
8. [验证与测试](#验证与测试)
9. [故障排除](#故障排除)
10. [维护与更新](#维护与更新)

## 概述

本指南提供了在AWS上部署Dify企业版的完整流程，包括基础设施创建、Kubernetes集群配置和应用部署。部署完成后，您将拥有一个完全功能的Dify企业版环境，支持所有企业级功能。

### 🎯 部署目标
- **完整的AWS基础设施**: VPC、EKS、RDS、ElastiCache、OpenSearch、S3等
- **Dify企业版应用**: 包含所有企业级功能和插件系统
- **高可用性配置**: 多可用区部署，自动扩缩容
- **安全最佳实践**: IRSA、网络隔离、加密存储

### 🏗️ 支持的功能
- ✅ 企业版核心服务 (enterprise)
- ✅ 企业版审计服务 (enterpriseAudit)
- ✅ 企业版前端 (enterpriseFrontend)
- ✅ 企业版网关 (gateway)
- ✅ 插件系统 (plugin_daemon, plugin_controller, plugin_connector)
- ✅ 代码沙箱 (sandbox)
- ✅ SSRF代理 (ssrfProxy)
- ✅ 文档解析服务 (unstructured)
- ✅ 多数据库支持 (dify, plugin_daemon, enterprise, audit)
- ✅ 外部服务集成 (PostgreSQL, Redis, OpenSearch, S3)

## 架构说明

### 🏛️ 整体架构

```
                                     AWS Cloud (Region: us-west-2)
┌────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │ VPC (10.0.0.0/16)                                                                       │   │
│  │                                                                                         │   │
│  │  ┌─────────────────┐        ┌─────────────────┐                                         │   │
│  │  │ Public Subnet 1 │        │ Public Subnet 2 │                                         │   │
│  │  │ 10.0.1.0/24     │        │ 10.0.2.0/24     │                                         │   │
│  │  │                 │        │                 │                                         │   │
│  │  │  ┌───────────┐  │        │  ┌───────────┐  │                                         │   │
│  │  │  │ NAT GW 1  │  │        │  │ NAT GW 2  │  │                                         │   │
│  │  │  └───────────┘  │        │  └───────────┘  │                                         │   │
│  │  └────────┬────────┘        └────────┬────────┘                                         │   │
│  │           │                          │                                                  │   │
│  │           │                          │                                                  │   │
│  │  ┌────────▼────────┐        ┌────────▼────────┐                                         │   │
│  │  │ Private Subnet 1│        │ Private Subnet 2│                                         │   │
│  │  │ 10.0.10.0/24    │        │ 10.0.11.0/24    │                                         │   │
│  │  │                 │        │                 │                                         │   │
│  │  │  ┌───────────┐  │        │  ┌───────────┐  │                                         │   │
│  │  │  │           │  │        │  │           │  │                                         │   │
│  │  │  │  EKS      ◄──┼────────┼──►           │  │                                         │   │
│  │  │  │  Cluster  │  │        │  │  EKS      │  │                                         │   │
│  │  │  │           │  │        │  │  Nodes    │  │                                         │   │
│  │  │  └─────┬─────┘  │        │  │           │  │                                         │   │
│  │  │        │        │        │  └─────┬─────┘  │                                         │   │
│  │  │        │        │        │        │        │                                         │   │
│  │  │        ▼        │        │        │        │                                         │   │
│  │  │  ┌───────────┐  │        │  ┌─────▼─────┐  │        ┌───────────────────────┐        │   │
│  │  │  │ Aurora    │  │        │  │           │  │        │                       │        │   │
│  │  │  │ Serverless│◄─┼────────┼──► Redis     │  │        │ ECR Repository        │        │   │
│  │  │  │ PostgreSQL│  │        │  │ Cache     │  │        │ (dify-test)           │        │   │
│  │  │  └───────────┘  │        │  └───────────┘  │        │                       │        │   │
│  │  │                 │        │                 │        └───────────────────────┘        │   │
│  │  │  ┌───────────┐  │        │  ┌───────────┐  │                                         │   │
│  │  │  │           │  │        │  │           │  │        ┌───────────────────────┐        │   │
│  │  │  │ OpenSearch│◄─┼────────┼──►           │  │        │                       │        │   │
│  │  │  │ Domain    │  │        │  │           │  │        │ S3 Bucket             │        │   │
│  │  │  └───────────┘  │        │  └───────────┘  │        │ (dify-test-storage)   │        │   │
│  │  │                 │        │                 │        │                       │        │   │
│  │  └─────────────────┘        └─────────────────┘        └───────────────────────┘        │   │
│  │                                                                                         │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 🔧 核心组件

#### 网络架构
- **VPC**: 10.0.0.0/16 CIDR块
- **公共子网**: 两个可用区的公共子网(10.0.1.0/24, 10.0.2.0/24)
- **私有子网**: 两个可用区的私有子网(10.0.10.0/24, 10.0.11.0/24)
- **NAT网关**: 每个公共子网一个NAT网关，用于私有子网访问互联网

#### 计算资源
- **EKS集群**: Kubernetes版本1.33，ARM架构Graviton处理器
- **测试环境**: 1个m7g.xlarge节点(4 vCPU, 16GB内存)
- **生产环境**: 6个m7g.2xlarge节点(8 vCPU, 32GB内存)

#### 数据存储
- **Aurora Serverless v2 PostgreSQL**: 版本17.5，支持多数据库
- **ElastiCache Redis**: 版本7.1，用于缓存和会话存储
- **OpenSearch**: 版本2.19，用于向量搜索和日志分析
- **S3**: 用于文件存储，启用版本控制和加密

## 前置要求

### 🔐 AWS账户要求
- AWS账户具有管理员权限
- 已配置AWS CLI和凭证
- 确认账户限制和配额满足要求

### 💻 本地环境要求
- **操作系统**: macOS、Linux或Windows (WSL2)
- **内存**: 至少8GB RAM
- **存储**: 至少20GB可用空间
- **网络**: 稳定的互联网连接

### 📋 必需信息
- AWS账户ID
- 部署区域 (推荐: us-west-2)
- 域名 (用于Dify访问)
- SSL证书 (可选，用于HTTPS)

## 工具安装与配置

### 1. AWS CLI 安装与配置

#### macOS安装
```bash
# 使用Homebrew安装
brew install awscli

# 或使用官方安装包
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

#### Linux安装
```bash
# 下载并安装
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### 配置AWS CLI
```bash
# 配置AWS凭证
aws configure

# 输入以下信息:
# AWS Access Key ID: [您的Access Key]
# AWS Secret Access Key: [您的Secret Key]
# Default region name: us-west-2
# Default output format: json

# 验证配置
aws sts get-caller-identity
```

### 2. Terraform 安装

#### macOS安装
```bash
# 使用Homebrew安装
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# 验证安装
terraform version
```

#### Linux安装
```bash
# 添加HashiCorp GPG密钥
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# 添加官方HashiCorp Linux仓库
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# 更新并安装Terraform
sudo apt update && sudo apt install terraform

# 验证安装
terraform version
```

### 3. kubectl 安装

#### macOS安装
```bash
# 使用Homebrew安装
brew install kubectl

# 验证安装
kubectl version --client
```

#### Linux安装
```bash
# 下载最新版本
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# 安装kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 验证安装
kubectl version --client
```

### 4. Helm 安装

#### macOS安装
```bash
# 使用Homebrew安装
brew install helm

# 验证安装
helm version
```

#### Linux安装
```bash
# 下载并安装
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 验证安装
helm version
```

### 5. PostgreSQL客户端安装

#### macOS安装
```bash
# 使用Homebrew安装
brew install postgresql

# 验证安装
psql --version
```

#### Linux安装
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install postgresql-client

# CentOS/RHEL
sudo yum install postgresql

# 验证安装
psql --version
```

## AWS服务配置

### 1. 环境变量设置

创建环境变量文件 `.env`:
```bash
# AWS配置
export AWS_REGION="us-west-2"
export AWS_ACCOUNT_ID="123456789012"  # 替换为您的AWS账户ID

# 环境配置
export TF_VAR_environment="test"  # 或 "prod"
export TF_VAR_aws_region="us-west-2"
export TF_VAR_aws_account_id="123456789012"

# Dify配置
export TF_VAR_dify_hostname="dify.yourdomain.com"  # 替换为您的域名
export TF_VAR_dify_ingress_enabled="true"
export TF_VAR_dify_ingress_class="alb"
export TF_VAR_dify_tls_enabled="true"

# 数据库配置
export TF_VAR_rds_username="postgres"
export TF_VAR_rds_password="$(openssl rand -base64 32)"
export TF_VAR_opensearch_password="$(openssl rand -base64 32)"

# Dify敏感配置 (自动生成强密钥)
export TF_VAR_dify_app_secret_key="$(openssl rand -base64 42)"
export TF_VAR_dify_admin_api_secret_key_salt="$(openssl rand -base64 32)"
export TF_VAR_dify_sandbox_api_key="$(openssl rand -base64 32)"
export TF_VAR_dify_inner_api_key="$(openssl rand -base64 32)"
export TF_VAR_dify_plugin_api_key="$(openssl rand -base64 32)"

# Helm配置
export TF_VAR_install_dify_chart="true"
export TF_VAR_dify_helm_repo_url="https://charts.dify.ai"
export TF_VAR_dify_helm_chart_name="dify"
export TF_VAR_dify_helm_chart_version="latest"
```

加载环境变量:
```bash
source .env
```

### 2. 验证AWS权限

```bash
# 检查当前用户身份
aws sts get-caller-identity

# 检查必需的服务权限
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query User.UserName --output text)

# 检查区域可用性
aws ec2 describe-availability-zones --region $AWS_REGION
```

## Terraform部署

### 1. 初始化Terraform

```bash
# 进入terraform目录
cd tf

# 初始化Terraform
terraform init

# 验证配置
terraform validate
```

### 2. 配置验证

运行配置验证脚本:
```bash
# 运行验证脚本
./validate_config.sh
```

预期输出:
```
🔍 验证Dify Helm配置...
📁 检查文件结构...
✅ 文件结构正确
📄 检查values.yaml文件内容...
✅ values.yaml 内容验证通过
🔧 检查terraform配置...
✅ terraform配置验证通过
🔑 检查必需变量...
✅ 必需变量验证通过
⚙️  检查helm配置...
✅ helm配置验证通过

🎉 所有验证通过！配置已正确更新。
```

### 3. 规划部署

```bash
# 生成部署计划
terraform plan -out=tfplan

# 查看计划摘要
terraform show -json tfplan | jq '.planned_values.root_module.resources | length'
```

### 4. 执行部署

```bash
# 应用配置 (首次部署约需20-30分钟)
terraform apply tfplan

# 或者交互式应用
terraform apply
```

部署过程中会创建以下资源:
- VPC和网络组件 (~5分钟)
- EKS集群 (~10-15分钟)
- RDS Aurora集群 (~5-10分钟)
- ElastiCache和OpenSearch (~5分钟)
- IAM角色和ServiceAccount (~2分钟)
- Helm部署Dify应用 (~5分钟)

### 5. 验证基础设施

```bash
# 检查EKS集群状态
aws eks describe-cluster --name $(terraform output -raw eks_cluster_name) --region $AWS_REGION

# 更新kubeconfig
aws eks update-kubeconfig --name $(terraform output -raw eks_cluster_name) --region $AWS_REGION

# 检查节点状态
kubectl get nodes

# 检查命名空间
kubectl get namespaces
```

## Dify企业版部署

### 1. 添加Helm仓库

```bash
# 添加Dify官方Helm仓库
helm repo add dify https://charts.dify.ai

# 更新仓库
helm repo update

# 验证仓库
helm search repo dify
```

### 2. 检查部署状态

```bash
# 检查Helm release状态
helm list -n dify

# 检查Pod状态
kubectl get pods -n dify

# 检查服务状态
kubectl get services -n dify
```

### 3. 验证企业版组件

```bash
# 检查企业版核心组件
kubectl get deployment -n dify | grep -E "(enterprise|audit|frontend|gateway)"

# 检查插件系统组件
kubectl get deployment -n dify | grep -E "(plugin|daemon|controller|connector)"

# 检查辅助服务
kubectl get deployment -n dify | grep -E "(sandbox|ssrf|unstructured)"
```

### 4. 检查数据库连接

```bash
# 获取数据库端点
DB_ENDPOINT=$(terraform output -raw aurora_cluster_endpoint)

# 检查数据库连接
PGPASSWORD=$TF_VAR_rds_password psql -h $DB_ENDPOINT -U $TF_VAR_rds_username -d dify -c "SELECT version();"

# 验证所有数据库已创建
PGPASSWORD=$TF_VAR_rds_password psql -h $DB_ENDPOINT -U $TF_VAR_rds_username -d dify -c "SELECT datname FROM pg_database WHERE datname IN ('dify', 'dify_plugin_daemon', 'dify_enterprise', 'dify_audit');"
```

### 5. 配置域名和SSL

#### 获取负载均衡器地址
```bash
# 获取ALB地址
kubectl get ingress -n dify dify-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

#### 配置DNS记录
在您的DNS提供商处创建CNAME记录:
```
dify.yourdomain.com -> k8s-dify-difyingr-xxxxxxxxxx-xxxxxxxxxx.us-west-2.elb.amazonaws.com
```

#### 配置SSL证书 (可选)
```bash
# 如果使用AWS Certificate Manager
aws acm request-certificate \
  --domain-name dify.yourdomain.com \
  --validation-method DNS \
  --region $AWS_REGION
```

## 验证与测试

### 1. 健康检查

```bash
# 检查所有Pod状态
kubectl get pods -n dify -o wide

# 检查服务端点
kubectl get endpoints -n dify

# 检查Ingress状态
kubectl describe ingress -n dify
```

### 2. 应用访问测试

```bash
# 测试内部访问
kubectl port-forward -n dify service/dify-api 5001:80 &

# 测试API健康检查
curl http://localhost:5001/health

# 停止端口转发
pkill -f "kubectl port-forward"
```

### 3. 功能验证清单

#### 基础功能
- [ ] Web界面可访问
- [ ] 用户注册/登录正常
- [ ] 应用创建功能正常
- [ ] 对话功能正常

#### 企业版功能
- [ ] 企业版控制台可访问
- [ ] 审计日志功能正常
- [ ] 用户管理功能正常
- [ ] 权限控制功能正常

#### 插件系统
- [ ] 插件市场可访问
- [ ] 插件安装功能正常
- [ ] 插件运行正常
- [ ] 自定义插件上传正常

#### 存储和数据
- [ ] 文件上传功能正常
- [ ] 数据持久化正常
- [ ] 向量搜索功能正常
- [ ] 缓存功能正常

### 4. 性能测试

```bash
# 简单的负载测试
kubectl run -i --tty load-test --image=busybox --rm --restart=Never -- sh

# 在容器内执行
while true; do
  wget -qO- http://dify-api.dify.svc.cluster.local/health
  sleep 1
done
```

## 远程部署最佳实践

### 使用终端复用器防止连接中断

在远程服务器上执行长时间运行的Terraform命令时，如果SSH连接中断，命令执行也会被中断。以下是几种解决方案，确保即使SSH连接断开，Terraform命令也能继续执行。

#### 方案一：使用 Screen（推荐）

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

# 如果你完全关闭了终端窗口，重新SSH登录到服务器后：
# 1. 列出所有screen会话
screen -ls
# 输出示例：
# There is a screen on:
#     12345.terraform  (Detached)
# 1 Socket in /var/run/screen/S-ec2-user.

# 2. 重新连接到已存在的会话
screen -r 12345.terraform  # 或简单地 screen -r terraform

# 如果有多个会话且名称相似，需要使用完整的会话ID
screen -r 12345
```

**Screen会话管理：**
```bash
# 终止/删除screen会话

# 方法1：从会话内部终止
exit  # 或按 Ctrl+D

# 方法2：从外部删除特定会话（适用于会话卡住或无法正常终止的情况）
screen -X -S [session-id] quit
# 例如：screen -X -S terraform quit
# 或：screen -X -S 12345.terraform quit

# 方法3：删除所有分离(detached)的会话
screen -wipe

# 方法4：强制删除所有会话（包括attached状态的会话）
pkill screen

# 方法5：如果会话显示为"Attached"但实际上已经断开连接
# 先强制分离
screen -D terraform
# 然后重新连接
screen -r terraform
# 最后正常退出
exit
```

**重要提示：**
- Screen会话在服务器重启后不会保留
- 删除会话会终止会话中运行的所有进程，确保在删除前保存重要的输出信息
- 即使完全关闭终端窗口或SSH连接断开，只要screen进程仍在远程服务器上运行，你都可以在新的终端会话中重新连接

#### 方案二：使用 Tmux

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

#### 方案三：使用 nohup 命令

如果不想使用终端复用器，可以使用nohup命令，它会忽略SIGHUP信号（当终端关闭时发送的信号）。

```bash
# 使用nohup执行terraform命令，并将输出重定向到文件
nohup terraform apply > terraform.log 2>&1 &

# 查看进程
ps aux | grep terraform

# 查看输出日志
tail -f terraform.log

# 将输出同时保存到文件（推荐）
terraform apply | tee output.$(date +%Y%m%d-%H%M%S).txt

# 或者保存计划和应用的输出
terraform plan -out=tfplan | tee plan.$(date +%Y%m%d-%H%M%S).txt
terraform apply tfplan | tee output.$(date +%Y%m%d-%H%M%S).txt
```

#### 最佳实践

1. **使用终端复用器**：对于交互式操作，推荐使用Screen或Tmux
2. **使用日志文件**：始终将输出重定向到日志文件，便于后续查看
3. **设置超时时间**：对于长时间运行的任务，考虑设置更长的SSH超时时间
4. **使用自动确认**：对于无人值守的操作，使用`-auto-approve`参数

## 故障排除

### 1. 常见问题

#### Terraform部署失败
```bash
# 检查Terraform状态
terraform state list

# 查看特定资源状态
terraform state show aws_eks_cluster.main

# 重新应用特定资源
terraform apply -target=aws_eks_cluster.main
```

#### Pod启动失败
```bash
# 查看Pod详细信息
kubectl describe pod -n dify <pod-name>

# 查看Pod日志
kubectl logs -n dify <pod-name> -c <container-name>

# 查看事件
kubectl get events -n dify --sort-by='.lastTimestamp'
```

#### 数据库连接问题
```bash
# 检查数据库状态
aws rds describe-db-clusters --db-cluster-identifier $(terraform output -raw aurora_cluster_endpoint | cut -d'.' -f1)

# 检查安全组规则
aws ec2 describe-security-groups --group-ids $(terraform output -raw rds_security_group_id)

# 测试数据库连接
kubectl run -i --tty db-test --image=postgres:17 --rm --restart=Never -- psql -h $DB_ENDPOINT -U $TF_VAR_rds_username -d dify
```

#### 网络连接问题
```bash
# 检查VPC配置
aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)

# 检查子网配置
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# 检查路由表
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
```

### 2. 日志收集

#### 收集系统日志
```bash
# 创建日志收集脚本
cat > collect_logs.sh << 'EOF'
#!/bin/bash
mkdir -p logs
kubectl get pods -n dify -o wide > logs/pods.log
kubectl get services -n dify > logs/services.log
kubectl get ingress -n dify > logs/ingress.log
kubectl describe nodes > logs/nodes.log
kubectl get events -n dify --sort-by='.lastTimestamp' > logs/events.log

# 收集主要组件日志
for pod in $(kubectl get pods -n dify -o name); do
  kubectl logs $pod -n dify > logs/$(echo $pod | sed 's/pod\///').log 2>/dev/null
done
EOF

chmod +x collect_logs.sh
./collect_logs.sh
```

#### 收集Terraform状态
```bash
# 导出Terraform状态
terraform show > terraform_state.log
terraform output > terraform_outputs.log
```

### 3. 恢复操作

#### 重启服务
```bash
# 重启特定部署
kubectl rollout restart deployment/dify-api -n dify

# 重启所有部署
kubectl rollout restart deployment -n dify
```

#### 数据库恢复
```bash
# 如果需要重新创建数据库
terraform taint null_resource.create_additional_databases
terraform apply -target=null_resource.create_additional_databases
```

## 维护与更新

### 1. 定期维护任务

#### 更新Helm Chart
```bash
# 更新Helm仓库
helm repo update

# 检查可用更新
helm search repo dify --versions

# 更新到最新版本
helm upgrade dify dify/dify -n dify
```

#### 更新官方values.yaml
```bash
# 获取最新的官方配置
helm show values dify/dify > tf/helm-values/values.yaml

# 验证配置
cd tf && ./validate_config.sh

# 应用更新
terraform plan
terraform apply
```

#### 系统更新
```bash
# 更新EKS节点
aws eks update-nodegroup-version \
  --cluster-name $(terraform output -raw eks_cluster_name) \
  --nodegroup-name $(terraform output -raw eks_nodegroup_name) \
  --region $AWS_REGION
```

### 2. 监控和告警

#### 设置CloudWatch监控
```bash
# 启用容器洞察
aws eks update-cluster-config \
  --name $(terraform output -raw eks_cluster_name) \
  --logging '{"enable":[{"types":["api","audit","authenticator","controllerManager","scheduler"]}]}' \
  --region $AWS_REGION
```

#### 配置告警
```bash
# 创建SNS主题用于告警
aws sns create-topic --name dify-alerts --region $AWS_REGION

# 订阅邮件通知
aws sns subscribe \
  --topic-arn arn:aws:sns:$AWS_REGION:$AWS_ACCOUNT_ID:dify-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com
```

### 3. 备份策略

#### 数据库备份
```bash
# Aurora自动备份已启用，手动创建快照
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier $(terraform output -raw aurora_cluster_endpoint | cut -d'.' -f1) \
  --db-cluster-snapshot-identifier dify-manual-snapshot-$(date +%Y%m%d%H%M%S) \
  --region $AWS_REGION
```

#### 配置备份
```bash
# 备份Kubernetes配置
kubectl get all -n dify -o yaml > dify-k8s-backup.yaml

# 备份Helm配置
helm get values dify -n dify > dify-helm-values-backup.yaml
```

### 4. 安全维护

#### 密钥轮换
```bash
# 生成新的API密钥
export TF_VAR_dify_app_secret_key="$(openssl rand -base64 42)"
export TF_VAR_dify_admin_api_secret_key_salt="$(openssl rand -base64 32)"
export TF_VAR_dify_sandbox_api_key="$(openssl rand -base64 32)"
export TF_VAR_dify_inner_api_key="$(openssl rand -base64 32)"
export TF_VAR_dify_plugin_api_key="$(openssl rand -base64 32)"

# 应用新密钥
terraform apply
```

#### 安全扫描
```bash
# 扫描容器镜像漏洞
aws ecr start-image-scan \
  --repository-name $(terraform output -raw ecr_repository_name) \
  --image-id imageTag=latest \
  --region $AWS_REGION
```

### 5. 成本优化

#### 资源使用分析
```bash
# 检查节点资源使用
kubectl top nodes

# 检查Pod资源使用
kubectl top pods -n dify

# 检查未使用的资源
kubectl get pods -n dify -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.requests.cpu}{"\t"}{.spec.containers[*].resources.requests.memory}{"\n"}{end}'
```

#### 环境管理
```bash
# 测试环境可以在非工作时间停止
# 停止EKS节点组 (仅测试环境)
aws eks update-nodegroup-config \
  --cluster-name $(terraform output -raw eks_cluster_name) \
  --nodegroup-name $(terraform output -raw eks_nodegroup_name) \
  --scaling-config minSize=0,maxSize=0,desiredSize=0 \
  --region $AWS_REGION

# 恢复节点组
aws eks update-nodegroup-config \
  --cluster-name $(terraform output -raw eks_cluster_name) \
  --nodegroup-name $(terraform output -raw eks_nodegroup_name) \
  --scaling-config minSize=1,maxSize=3,desiredSize=1 \
  --region $AWS_REGION
```

## 🗑️ 资源清理与删除

### 完全删除部署

如果需要完全删除Dify企业版部署和所有AWS资源，请按以下步骤操作：

#### ⚠️ 重要警告
- **数据丢失**: 删除操作将永久删除所有数据，包括数据库、文件存储等
- **不可逆**: 删除操作无法撤销，请确保已备份重要数据
- **费用影响**: 删除后将停止产生AWS费用，但已产生的费用仍需支付

#### 1. 备份重要数据（可选但推荐）

```bash
# 备份数据库
DB_ENDPOINT=$(terraform output -raw aurora_cluster_endpoint)
PGPASSWORD=$TF_VAR_rds_password pg_dump -h $DB_ENDPOINT -U $TF_VAR_rds_username dify > dify_backup.sql
PGPASSWORD=$TF_VAR_rds_password pg_dump -h $DB_ENDPOINT -U $TF_VAR_rds_username dify_plugin_daemon > plugin_daemon_backup.sql
PGPASSWORD=$TF_VAR_rds_password pg_dump -h $DB_ENDPOINT -U $TF_VAR_rds_username dify_enterprise > enterprise_backup.sql
PGPASSWORD=$TF_VAR_rds_password pg_dump -h $DB_ENDPOINT -U $TF_VAR_rds_username dify_audit > audit_backup.sql

# 备份S3数据
S3_BUCKET=$(terraform output -raw s3_bucket_name)
aws s3 sync s3://$S3_BUCKET ./s3_backup/

# 备份Kubernetes配置
kubectl get all -n dify -o yaml > dify_k8s_backup.yaml
helm get values dify -n dify > dify_helm_values_backup.yaml
```

#### 2. 删除Helm部署

```bash
# 删除Dify应用
helm uninstall dify -n dify

# 删除其他Helm releases（如果安装了）
helm uninstall aws-load-balancer-controller -n kube-system
helm uninstall nginx-ingress -n ingress-nginx
helm uninstall cert-manager -n cert-manager
helm uninstall kube-prometheus-stack -n monitoring

# 删除命名空间
kubectl delete namespace dify
kubectl delete namespace ingress-nginx
kubectl delete namespace cert-manager
kubectl delete namespace monitoring
```

#### 3. 执行Terraform销毁

```bash
# 进入terraform目录
cd tf

# 生成销毁计划（可选，用于预览将要删除的资源）
terraform plan -destroy -out=destroy.tfplan

# 查看销毁计划
terraform show destroy.tfplan

# 执行销毁操作
terraform destroy

# 或者使用计划文件
terraform apply destroy.tfplan
```

#### 4. 销毁过程说明

Terraform将按以下顺序删除资源：

1. **Helm Releases** (~2-3分钟)
   - Dify应用和相关组件

2. **Kubernetes资源** (~2-3分钟)
   - ServiceAccounts、ConfigMaps、Secrets等

3. **EKS集群** (~10-15分钟)
   - 节点组、集群控制平面

4. **数据库和缓存** (~5-10分钟)
   - Aurora集群、ElastiCache集群

5. **网络资源** (~5-10分钟)
   - VPC、子网、路由表、NAT网关等

6. **存储和其他资源** (~2-5分钟)
   - S3存储桶、ECR仓库、IAM角色等

**总预计时间**: 25-45分钟

#### 5. 验证删除完成

```bash
# 检查terraform状态
terraform state list

# 检查AWS资源（应该返回空或错误）
aws eks describe-cluster --name $(terraform output -raw eks_cluster_name) --region $AWS_REGION
aws rds describe-db-clusters --db-cluster-identifier $(terraform output -raw aurora_cluster_endpoint | cut -d'.' -f1)

# 检查S3存储桶
aws s3 ls | grep $(terraform output -raw s3_bucket_name)
```

#### 6. 手动清理（如果需要）

如果terraform destroy失败或有残留资源，可能需要手动清理：

```bash
# 清理ECR镜像
aws ecr list-images --repository-name $(terraform output -raw ecr_repository_name) --region $AWS_REGION
aws ecr batch-delete-image --repository-name $(terraform output -raw ecr_repository_name) --image-ids imageTag=latest

# 清理S3存储桶内容
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive

# 清理CloudWatch日志组
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/$(terraform output -raw eks_cluster_name)"
aws logs delete-log-group --log-group-name "/aws/eks/$(terraform output -raw eks_cluster_name)/cluster"
```

### 部分删除场景

#### 只删除应用，保留基础设施

```bash
# 只删除Helm部署
helm uninstall dify -n dify

# 保留EKS集群和其他AWS资源
# 这样可以重新部署应用而不需要重建基础设施
```

#### 删除特定组件

```bash
# 删除特定的terraform资源
terraform destroy -target=helm_release.dify
terraform destroy -target=aws_opensearch_domain.main
```

### 成本优化删除

#### 临时停止（测试环境）

```bash
# 缩减EKS节点组到0（停止计算费用）
aws eks update-nodegroup-config \
  --cluster-name $(terraform output -raw eks_cluster_name) \
  --nodegroup-name $(terraform output -raw eks_nodegroup_name) \
  --scaling-config minSize=0,maxSize=0,desiredSize=0 \
  --region $AWS_REGION

# 停止Aurora集群（保留数据）
aws rds stop-db-cluster --db-cluster-identifier $(terraform output -raw aurora_cluster_endpoint | cut -d'.' -f1)
```

#### 恢复服务

```bash
# 恢复EKS节点组
aws eks update-nodegroup-config \
  --cluster-name $(terraform output -raw eks_cluster_name) \
  --nodegroup-name $(terraform output -raw eks_nodegroup_name) \
  --scaling-config minSize=1,maxSize=3,desiredSize=1 \
  --region $AWS_REGION

# 启动Aurora集群
aws rds start-db-cluster --db-cluster-identifier $(terraform output -raw aurora_cluster_endpoint | cut -d'.' -f1)
```

### 删除故障排除

#### 常见删除问题

1. **VPC删除失败**
   ```bash
   # 检查是否有残留的网络接口
   aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
   
   # 手动删除网络接口
   aws ec2 delete-network-interface --network-interface-id <interface-id>
   ```

2. **S3存储桶删除失败**
   ```bash
   # 清空存储桶内容
   aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive
   
   # 删除存储桶版本
   aws s3api delete-bucket --bucket $(terraform output -raw s3_bucket_name)
   ```

3. **IAM角色删除失败**
   ```bash
   # 分离策略
   aws iam list-attached-role-policies --role-name <role-name>
   aws iam detach-role-policy --role-name <role-name> --policy-arn <policy-arn>
   
   # 删除角色
   aws iam delete-role --role-name <role-name>
   ```

#### 强制删除

```bash
# 如果terraform destroy卡住，可以强制删除
terraform destroy -auto-approve -parallelism=20

# 或者删除terraform状态（谨慎使用）
terraform state rm <resource-name>
```

### 删除后清理

```bash
# 清理本地terraform状态
rm -rf .terraform/
rm terraform.tfstate*
rm tfplan destroy.tfplan

# 清理kubectl配置
kubectl config delete-context $(kubectl config current-context)
kubectl config delete-cluster $(terraform output -raw eks_cluster_name)

# 清理Helm仓库
helm repo remove dify
```

## 📞 支持与帮助

### 官方资源
- [Dify官方文档](https://docs.dify.ai/)
- [Dify GitHub仓库](https://github.com/langgenius/dify)
- [Helm Chart文档](https://github.com/langgenius/dify-helm)

### 社区支持
- [Dify Discord社区](https://discord.gg/dify)
- [GitHub Issues](https://github.com/langgenius/dify/issues)

### 紧急联系
如遇到紧急问题，请：
1. 收集相关日志和错误信息
2. 检查[故障排除](#故障排除)部分
3. 在GitHub上创建Issue并提供详细信息

---

## 🎉 部署完成

恭喜！您已成功部署了Dify企业版。现在您可以：

1. **访问应用**: 通过配置的域名访问Dify
2. **创建管理员账户**: 首次访问时创建管理员账户
3. **配置企业设置**: 在企业版控制台中配置相关设置
4. **开始使用**: 创建您的第一个AI应用

记住定期执行维护任务，保持系统的安全性和性能！