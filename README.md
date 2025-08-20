# Dify 企业版 AWS 基础设施部署
# Dify Enterprise AWS Infrastructure Deployment



## 🔧 完整部署流程
## 🔧 Complete Deployment Process

### 阶段一：部署AWS基础设施
### Stage 1: Deploy AWS Infrastructure

```bash
# 1. 克隆仓库 | Clone repository
git clone <repository-url>

# 2. 确认权限 | Check permissions
bash tf/check_aws_permissions.sh

# 3. 配置变量 | Configure variables
cp tf/terraform.tfvars.example tf/terraform.tfvars

# 编辑 terraform.tfvars 文件，设置：| Edit terraform.tfvars file and set:
# - environment = "test" 或 "prod" | "test" or "prod"
# - aws_region = "your-region"
# - aws_account_id = "your-account-id"

# 4. 部署基础设施 | Deploy infrastructure
cd tf
terraform init
terraform plan
terraform apply -auto-approve
```

### 阶段二：验证部署并生成配置
### Stage 2: Verify Deployment and Generate Configuration

```bash
# 1. 验证基础设施状态 | Verify infrastructure status
cd tf
bash verify_deployment.sh

# 2. 生成Dify部署配置 | Generate Dify deployment configuration
bash post_apply.sh
```




### 常见问题解决
### Common Issues and Solutions

#### 1. 权限问题 | Permission Issues
```bash
# 检查AWS凭证 | Check AWS credentials
aws sts get-caller-identity

# 检查EKS访问 | Check EKS access
aws eks describe-cluster --name <cluster-name>
```

#### 2. 网络连接问题 | Network Connection Issues
```bash
# 更新kubeconfig | Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# 测试连接 | Test connection
kubectl get nodes
```

#### 3. Terraform状态问题 | Terraform State Issues
```bash
# 检查状态 | Check state
terraform show

# 刷新状态 | Refresh state
terraform refresh
```



## 🔄 维护和更新
## 🔄 Maintenance and Updates

### 配置更新 | Configuration Updates
```bash
# 重新生成配置 | Regenerate configuration
./generate_dify_config.sh

# 更新Helm部署 | Update Helm deployment
helm upgrade dify -f dify_values_*.yaml dify/dify -n dify
```

### 基础设施更新 | Infrastructure Updates
```bash
# 更新Terraform配置 | Update Terraform configuration
terraform plan
terraform apply


## 🗑️ 资源清理
## 🗑️ Resource Cleanup

```bash
# 删除Dify应用 | Delete Dify application
helm uninstall dify -n dify

# 删除基础设施 | Delete infrastructure
cd tf
terraform destroy
```

⚠️ **警告**: 此操作将永久删除所有数据，请先备份重要信息。
⚠️ **Warning**: This operation will permanently delete all data. Please backup important information first.

## 🔒 安全注意事项
## 🔒 Security Considerations

### 敏感文件管理 | Sensitive File Management
- 生成的配置文件包含密码和密钥 | Generated configuration files contain passwords and keys
- 文件权限自动设置为600 | File permissions are automatically set to 600
- 不要提交敏感文件到版本控制 | Do not commit sensitive files to version control

### 密钥轮换 | Key Rotation
```bash
# 定期更换数据库密码 | Regularly change database passwords
# 更新API密钥和应用密钥 | Update API keys and application keys
# 轮换IRSA角色权限 | Rotate IRSA role permissions
```

### 域名配置 | Domain Configuration
```bash
# 修改所有默认域名 | Modify all default domain names
consoleApiDomain: "console.your-company.com"
serviceApiDomain: "api.your-company.com"
appApiDomain: "app.your-company.com"
```

## 📖 参考文档
## 📖 Reference Documentation

- [Dify企业版官方文档 | Dify Enterprise Official Documentation](https://enterprise-docs.dify.ai/)
- [Helm Chart配置 | Helm Chart Configuration](https://langgenius.github.io/dify-helm/)
- [AWS EKS文档 | AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes IRSA配置 | Kubernetes IRSA Configuration](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## 🤝 贡献
## 🤝 Contributing

欢迎提交Issue和Pull Request来改进这个项目。
Welcome to submit Issues and Pull Requests to improve this project.

## 🆘 支持
## 🆘 Support

如遇到问题，请：| If you encounter issues, please:
1. 运行验证脚本检查资源状态 | Run verification scripts to check resource status
2. 查看生成的验证报告 | Review generated verification reports
3. 检查CloudWatch日志 | Check CloudWatch logs
4. 在GitHub上创建Issue并提供详细信息 | Create an Issue on GitHub with detailed information

## 📄 许可证
## 📄 License

本项目采用MIT许可证。详见[LICENSE](LICENSE)文件。
This project is licensed under the MIT License. See [LICENSE](LICENSE) file for details.


