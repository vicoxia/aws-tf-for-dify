# Dify 企业版 AWS 基础设施部署

本仓库包含在AWS上部署Dify企业版所需基础设施的Terraform配置。

## 🚀 重要说明

**此Terraform方案专门用于部署AWS基础设施，不包括Dify应用的部署。**

部署流程分为两个阶段：
1. **阶段一**：使用此Terraform方案部署AWS基础设施
2. **阶段二**：按照 `additional_docs` 目录下的部署文档手工部署Dify应用

## 📖 部署指南

### 基础设施部署
- **主要指南**: [DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md](DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md)
- **详细指南**: [tf/AWS_INFRASTRUCTURE_DEPLOYMENT_GUIDE.md](tf/AWS_INFRASTRUCTURE_DEPLOYMENT_GUIDE.md)

### Dify应用部署
- **测试环境**: [additional_docs/测试环境部署.md](additional_docs/测试环境部署.md)
- **生产环境**: [additional_docs/生产环境部署.md](additional_docs/生产环境部署.md)

## 🏗️ 部署的AWS基础设施

### 核心服务
- **EKS集群**: Kubernetes控制平面和工作节点
- **Aurora PostgreSQL**: 主数据库服务
- **ElastiCache Redis**: 缓存和会话存储
- **OpenSearch**: 向量数据库服务
- **S3存储桶**: 文件存储
- **ECR仓库**: 容器镜像存储

### 网络和安全
- **VPC**: 网络隔离和安全
- **子网**: 公有和私有子网，多可用区部署
- **安全组**: 网络访问控制
- **IAM角色**: 为IRSA提供权限策略

### Kubernetes基础组件
- **Dify命名空间**: 应用部署的专用命名空间
- **IRSA ServiceAccounts**: 为Dify应用提供AWS权限的服务账户

### 可选组件（通过变量控制）
- **AWS Load Balancer Controller**: ALB/NLB支持
- **NGINX Ingress Controller**: 流量路由
- **Cert-Manager**: SSL证书管理

## 🔧 快速开始

### 1. 部署AWS基础设施

```bash
# 克隆仓库
git clone <repository-url>
cd dify-aws-terraform

# 配置变量
cp tf/terraform.tfvars.example tf/terraform.tfvars
# 编辑 terraform.tfvars 文件

# 部署基础设施
cd tf
terraform init
terraform plan
terraform apply

# 配置kubectl
aws eks update-kubeconfig --region us-west-2 --name dify-eks-cluster

# 验证基础设施部署
kubectl get nodes
kubectl get namespaces
kubectl get serviceaccounts -n dify
```

### 2. 部署Dify应用

基础设施部署完成后，按照以下文档部署Dify应用：

- **测试环境**: [additional_docs/测试环境部署.md](additional_docs/测试环境部署.md)
- **生产环境**: [additional_docs/生产环境部署.md](additional_docs/生产环境部署.md)

## 📊 环境配置

### 测试环境 (`environment = "test"`)
- 较小的实例规格
- 基本配置
- 成本优化

### 生产环境 (`environment = "prod"`)  
- 高可用配置
- 更大的实例规格
- 完整监控

## 🔐 安全特性

- **IRSA集成**: 无需在Pod中存储AWS凭证
- **网络隔离**: 私有子网部署，安全组控制
- **加密存储**: S3和RDS数据加密
- **最小权限**: IAM角色遵循最小权限原则

## 📈 监控和日志

基础设施监控通过AWS CloudWatch提供：
- EKS集群监控
- RDS数据库监控
- ElastiCache监控
- OpenSearch监控

## 🛠️ 维护和运维

### 备份策略
- RDS自动备份和快照
- S3版本控制和生命周期管理
- 跨区域复制（可选）

### 扩缩容
- EKS节点组自动扩缩容
- 应用级别HPA支持
- 数据库读副本扩展

## 💰 成本优化

- Spot实例支持（非生产环境）
- 合适的实例规格选择
- S3智能分层存储
- 预留实例（生产环境）

## 🔧 故障排除

常见问题和解决方案请参考：
- [AWS基础设施部署指南](tf/AWS_INFRASTRUCTURE_DEPLOYMENT_GUIDE.md#故障排除)
- [完整部署指南](DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md#故障排除)

## 📚 文档结构

```
├── README.md                                    # 项目概述
├── DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md         # 主要部署指南
├── tf/
│   ├── AWS_INFRASTRUCTURE_DEPLOYMENT_GUIDE.md  # 详细基础设施指南
│   ├── *.tf                                    # Terraform配置文件
│   └── terraform.tfvars.example                # 配置示例
└── additional_docs/
    ├── 测试环境部署.md                          # 测试环境Dify部署
    ├── 生产环境部署.md                          # 生产环境Dify部署
    └── 其他相关文档...
```

## 🗑️ 资源清理

如需删除部署的所有AWS资源：

```bash
cd tf
terraform destroy
```

⚠️ **警告**: 此操作将永久删除所有数据，请先备份重要信息。详细的删除指南请参考[完整部署指南](DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md#资源清理与删除)。

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目。

## 🆘 支持

如遇到问题，请：
1. 查看[完整部署指南](DIFY_ENTERPRISE_DEPLOYMENT_GUIDE.md)中的故障排除部分
2. 查看[AWS基础设施部署指南](tf/AWS_INFRASTRUCTURE_DEPLOYMENT_GUIDE.md)
3. 在GitHub上创建Issue并提供详细信息

## 📄 许可证

本项目采用MIT许可证。详见[LICENSE](LICENSE)文件。


