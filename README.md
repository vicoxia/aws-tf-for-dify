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

# 更好的做法：保存计划并应用相同的计划
terraform plan -out=tfplan
terraform apply tfplan

# 这样可以确保apply执行的操作与plan阶段完全一致
# 当你看到提示"Note: You didn't use the -out option to save this plan..."时，
# 建议使用上述方法保存计划，特别是对于大型或复杂的部署

# 执行部署（标准方式，但可能与plan阶段有差异）
terraform apply

# 调整并发数量以加速部署
terraform apply -parallelism=20  # 默认值为10

# 将输出同时保存到文件
terraform apply | tee output.$(date +%Y%m%d-%H%M%S).txt

# 或者保存计划和应用的输出
terraform plan -out=tfplan | tee plan.$(date +%Y%m%d-%H%M%S).txt
terraform apply tfplan | tee output.$(date +%Y%m%d-%H%M%S).txt
```

**说明**：使用`tee`命令可以将输出同时显示在控制台和保存到文件中，文件名包含当前日期和时间，便于区分不同的部署记录。

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
# 标准方式：删除所有资源
terraform destroy

# 确认删除时输入 "yes"

# 注意：与 terraform apply 不同，terraform destroy 不需要指定计划文件
# 错误用法：terraform destroy "tfplan"

# 如果需要生成销毁计划文件（可选）
terraform plan -destroy -out=destroy.tfplan

# 应用销毁计划
terraform apply destroy.tfplan
```

**说明**：
1. `terraform destroy` 命令会自动创建一个删除所有资源的计划，并在执行前显示这个计划供用户确认
2. 不需要在 `terraform destroy` 后面加上之前用于部署的计划文件 "tfplan"
3. 如果希望先查看销毁计划再执行，可以使用 `terraform plan -destroy` 命令
4. 对于需要在无人值守模式下执行的情况，可以使用 `terraform destroy -auto-approve`

## 故障排除

### 1. EKS 节点无法加入集群
- 检查子网路由表配置
- 验证安全组规则
- 确认 IAM 角色权限
- 检查 aws-auth ConfigMap 配置（见下文）

### 2. AWS控制台显示"No nodes"但kubectl可以看到节点

有时候在AWS控制台中，EKS集群的node group可能显示"No nodes"，但使用`kubectl get nodes`命令可以看到节点并且状态为Ready。这种不一致可能由以下原因导致：

1. **控制台刷新延迟**：AWS控制台可能需要几分钟时间来刷新和显示最新的节点状态
   - 解决方法：等待几分钟后刷新页面，或者尝试清除浏览器缓存

2. **节点标签问题**：节点可能缺少AWS控制台用来识别它属于特定节点组的标签
   - 解决方法：检查节点是否有正确的标签，特别是`eks:nodegroup-name`标签
   ```bash
   kubectl describe node <node-name> | grep eks:nodegroup-name
   ```

3. **IAM角色配置**：节点的IAM角色可能没有正确配置或权限不足
   - 解决方法：确认节点IAM角色有正确的策略，特别是`AmazonEKSWorkerNodePolicy`和`AmazonEKS_CNI_Policy`

4. **AWS控制台bug**：有时这可能是AWS控制台的显示问题
   - 解决方法：使用AWS CLI验证节点状态
   ```bash
   aws eks list-nodegroups --cluster-name <cluster-name>
   aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>
   ```

5. **节点组和节点不匹配**：节点可能已加入集群但未正确关联到节点组
   - 解决方法：检查节点是否使用了正确的用户数据脚本加入集群
   ```bash
   # 查看节点的用户数据脚本中的集群名称和节点组名称
   aws ec2 describe-instances --instance-ids <instance-id> --query 'Reservations[].Instances[].UserData' --output text | base64 --decode
   ```

**重要提示**：如果节点在kubectl中显示为Ready，通常意味着它已经正确加入集群并且可以运行工作负载，即使AWS控制台显示有问题。在这种情况下，集群功能不受影响。

### 3. Aurora 数据库连接问题

### 查看和管理 EKS 集群的 aws-auth ConfigMap

aws-auth ConfigMap 是 EKS 集群中的关键组件，用于控制哪些 IAM 实体（用户和角色）可以访问 Kubernetes API。

#### 通过 AWS 控制台查看

AWS 控制台没有直接查看 ConfigMap 的界面，但可以通过以下步骤访问：
s
1. 登录 AWS 控制台
2. 导航到 EKS 服务
3. 选择您的集群
4. 点击"访问"选项卡
5. 在"访问条目"部分，您可以看到集群的访问配置
6. 要查看完整的 aws-auth ConfigMap，需要使用 kubectl 命令行工具

#### 使用 kubectl 查看和管理

```bash
# 配置 kubectl 以连接到您的 EKS 集群
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# 查看 aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml

# 编辑 aws-auth ConfigMap
kubectl edit configmap aws-auth -n kube-system

# 或者，将 ConfigMap 导出到文件，编辑后应用
kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth.yaml
# 编辑 aws-auth.yaml 文件
kubectl apply -f aws-auth.yaml
```

#### 常见的 aws-auth ConfigMap 格式

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::<account-id>:role/<node-role-name>
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    # 可以添加其他 IAM 角色
    - rolearn: arn:aws:iam::<account-id>:role/<admin-role-name>
      username: admin
      groups:
        - system:masters
  mapUsers: |
    # 可以添加 IAM 用户
    - userarn: arn:aws:iam::<account-id>:user/<username>
      username: admin
      groups:
        - system:masters
```

#### 故障排除提示

1. **节点无法加入集群**：确保节点组 IAM 角色正确映射在 aws-auth ConfigMap 中
2. **权限问题**：检查用户或角色是否正确映射到适当的 Kubernetes 组
3. **ConfigMap 损坏**：如果 ConfigMap 被错误编辑，可能需要重新创建它
4. **自动更新**：添加新的节点组时，EKS 会自动更新 aws-auth ConfigMap

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

Screen是一个终端复用器，允许你在一个终端会话中打开多个窗口，并且在断开连接后保持会话运行。**即使完全关闭终端窗口或SSH连接断开，只要screen进程仍在远程服务器上运行，你都可以在新的终端会话中重新连接到之前的screen会话。**

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

**注意**：
1. Screen会话在服务器重启后不会保留。如果需要在服务器重启后自动恢复会话，请考虑使用systemd服务方案。
2. 删除会话会终止会话中运行的所有进程，确保在删除前保存重要的输出信息。

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
