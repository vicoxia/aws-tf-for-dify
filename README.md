# Dify 企业版 AWS 部署

本仓库包含在AWS上部署Dify企业版的完整Terraform配置和部署指南。

## 🚀 快速开始

**完整部署指南**: [DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md](DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md)

这是一份详细的端到端部署指南，包含：
- 工具安装与配置
- AWS服务配置  
- Terraform部署
- Dify企业版部署
- 验证与测试
- 故障排除
- 维护与更新

## 🏗️ 架构概览

部署的基础设施包括：
- **VPC**: 公有和私有子网，多可用区部署
- **EKS集群**: Kubernetes工作负载，ARM架构Graviton处理器
- **Aurora Serverless v2**: PostgreSQL数据库，支持多数据库实例
- **ElastiCache Redis**: 缓存和会话存储
- **OpenSearch**: 向量搜索和日志分析
- **S3存储桶**: 文件存储，启用版本控制和加密
- **ECR仓库**: 容器镜像存储

## 📋 支持的功能

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

## 🔧 快速部署

**💡 远程部署提醒**: 如果在远程服务器上部署，建议使用 `screen` 或 `tmux` 防止SSH连接中断导致部署失败。详见[完整部署指南](DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md#远程部署最佳实践)中的远程部署最佳实践部分。

```bash
# 1. 克隆仓库
git clone <repository-url>
cd aws-tf-for-dify

# 2. 配置环境变量
export TF_VAR_environment="test"
export TF_VAR_aws_region="us-west-2"
export TF_VAR_aws_account_id="your-account-id"
export TF_VAR_dify_hostname="dify.yourdomain.com"

# 生成安全密钥
export TF_VAR_dify_app_secret_key="$(openssl rand -base64 42)"
export TF_VAR_dify_admin_api_secret_key_salt="$(openssl rand -base64 32)"
export TF_VAR_dify_sandbox_api_key="$(openssl rand -base64 32)"
export TF_VAR_dify_inner_api_key="$(openssl rand -base64 32)"
export TF_VAR_dify_plugin_api_key="$(openssl rand -base64 32)"

# 3. 部署基础设施
cd tf
terraform init
./validate_config.sh
terraform plan
terraform apply
```

## 📚 文档结构

- **[DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md](DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md)** - 完整部署指南
- **[deployment-architecture.md](deployment-architecture.md)** - 架构详细说明
- **[tf/DIFY_EE_UPGRADE_COMPLIANCE.md](tf/DIFY_EE_UPGRADE_COMPLIANCE.md)** - 升级指南合规性检查
- **[tf/validate_config.sh](tf/validate_config.sh)** - 配置验证脚本

## 🗑️ 资源清理

如需删除部署的所有AWS资源：

```bash
cd tf
terraform destroy
```

⚠️ **警告**: 此操作将永久删除所有数据，请先备份重要信息。详细的删除指南请参考[完整部署指南](DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md#资源清理与删除)。

## 🆘 支持

如遇到问题，请：
1. 查看[完整部署指南](DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md)中的故障排除部分
2. 运行 `cd tf && ./validate_config.sh` 检查配置
3. 在GitHub上创建Issue并提供详细信息

## 📄 许可证

本项目遵循相应的开源许可证。


