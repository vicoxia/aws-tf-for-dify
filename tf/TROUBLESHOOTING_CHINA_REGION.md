# 中国区部署故障排除指南

## 常见错误及解决方案

### 1. RDS HTTP Endpoint 错误

**错误信息**:
```
Error: enabling HTTP endpoint for RDS Cluster: operation error RDS: EnableHttpEndpoint, 
https response error StatusCode: 400, RequestID: xxx, api error InvalidAction: 
EnableHttpEndpoint is not available in this region.
```

**原因**: 中国区不支持 RDS Data API (HTTP Endpoint)

**解决方案**:

#### 方法一：强制重新创建 RDS 集群
```bash
terraform taint aws_rds_cluster.main
terraform apply
```

#### 方法二：手动修改状态（高级用户）
```bash
# 导入当前状态
terraform state pull > state.json

# 编辑 state.json，将 enable_http_endpoint 设置为 false
# 然后导入回去
terraform state push state.json
```

#### 方法三：删除并重新创建
```bash
# 注意：这会删除数据库！仅在测试环境使用
terraform destroy -target=aws_rds_cluster.main
terraform apply
```

### 2. Helm 仓库访问超时

**错误信息**:
```
Error: could not download chart: looks like "https://aws.github.io/eks-charts" 
is not a valid chart repository or cannot be reached
```

**解决方案**:

#### 方法一：使用备用仓库
在 `terraform.tfvars` 中添加：
```hcl
custom_helm_repositories = {
  aws_load_balancer_controller = "https://g-hsod9681-helm.pkg.coding.net/dify-artifact/eks-charts"
}
```

#### 方法二：配置代理
```bash
export HTTP_PROXY=http://your-proxy:port
export HTTPS_PROXY=http://your-proxy:port
terraform apply
```

#### 方法三：禁用有问题的组件
```hcl
install_aws_load_balancer_controller = false
install_nginx_ingress = true
```

### 3. IAM 策略 ARN 格式错误

**错误信息**:
```
Error: creating IAM Policy: MalformedPolicyDocument: 
Partition "aws" is not valid for resource "arn:aws:..."
```

**解决方案**:
检查 `terraform.tfvars` 中的区域设置：
```hcl
aws_region = "cn-northwest-1"  # 确保设置正确
```

然后重新应用：
```bash
terraform plan  # 检查 ARN 格式是否正确
terraform apply
```

### 4. 网络连通性问题

**症状**: 各种超时错误

**诊断步骤**:
```bash
# 运行网络连通性测试
./verify_china_helm_repos.sh

# 测试具体的仓库
curl -I https://aws.github.io/eks-charts
curl -I https://g-hsod9681-helm.pkg.coding.net/dify-artifact/eks-charts
```

**解决方案**:
1. 配置企业代理
2. 使用中国区镜像仓库
3. 下载 Charts 到本地

### 5. 数据库创建失败

#### 5.1 RDS Data API 错误（已自动修复）
**错误信息**:
```
Error: Could not connect to the endpoint URL: 
"https://rds-data.cn-northwest-1.amazonaws.com.cn/Execute"
```

**原因**: 中国区不支持 RDS Data API

**解决方案**: 
系统现在会自动使用直连模式，无需手动处理。

#### 5.2 PostgreSQL 连接失败
**错误信息**:
```
psql: could not connect to server: Connection timed out
```

**解决方案**:
1. 检查网络连通性
2. 确认安全组配置
3. 验证 VPC 路由设置

#### 5.3 依赖工具缺失
**错误信息**:
```
PostgreSQL 客户端 (psql) 未安装
```

**解决方案**:
```bash
# 安装必要工具
sudo apt-get install postgresql-client jq  # Ubuntu/Debian
sudo yum install postgresql jq              # CentOS/RHEL
brew install postgresql jq                  # macOS
```

## 预防措施

### 1. 部署前检查清单

- [ ] 确认 `aws_region` 设置为中国区域
- [ ] 检查网络连通性
- [ ] 准备备用 Helm 仓库地址
- [ ] 了解中国区限制

### 2. 推荐的中国区配置

```hcl
# terraform.tfvars
aws_region = "cn-northwest-1"
aws_account_id = "your-account-id"

# 使用备用仓库（可选）
custom_helm_repositories = {
  aws_load_balancer_controller = "https://g-hsod9681-helm.pkg.coding.net/dify-artifact/eks-charts"
}

# 其他配置保持默认
environment = "test"
install_aws_load_balancer_controller = true
```

### 3. 验证脚本

使用提供的验证脚本：
```bash
# 验证区域检测
terraform plan | grep "china_region_detection_test"

# 验证网络连通性
./verify_china_helm_repos.sh

# 修复 RDS 问题
./fix_china_region_rds.sh
```

## 获取帮助

如果遇到其他问题：

1. 检查 Terraform 日志：`TF_LOG=DEBUG terraform apply`
2. 查看 AWS CloudTrail 日志
3. 参考相关文档：
   - `CHINA_REGION_DEPLOYMENT_GUIDE.md`
   - `CHINA_REGION_NETWORK_SOLUTIONS.md`
   - `create_dify_databases_china.md`

## 常用命令

```bash
# 检查当前状态
terraform state list
terraform state show aws_rds_cluster.main

# 强制刷新状态
terraform refresh

# 重新创建特定资源
terraform taint <resource_name>
terraform apply

# 查看计划
terraform plan -out=plan.out
terraform show plan.out
```