# Dify 企业版 AWS 基础设施部署



## 🔧 完整部署流程

### 阶段一：部署AWS基础设施

```bash
# 1. 克隆仓库
git clone <repository-url>
cd dify-aws-terraform

# 2. 确认权限

bash tf/check_aws_permissions.sh

# 3. 配置变量
cp tf/terraform.tfvars.example tf/terraform.tfvars

# 编辑 terraform.tfvars 文件，设置：
# - environment = "test" 或 "prod"
# - aws_region = "your-region"
# - aws_account_id = "your-account-id"

# 4. 部署基础设施
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


