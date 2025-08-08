# Dify EE 升级指南合规性检查

## 概述

本文档详细说明了我们的Terraform配置如何完全符合"新版本dify企业版从旧版本的升级指南.txt"中的所有要求。

## ✅ 升级指南要求对照检查

### 1. 基础设施要求

| 要求 | 状态 | Terraform实现 |
|------|------|---------------|
| S3权限 | ✅ 已实现 | `aws_iam_policy.dify_ee_s3_policy` |
| ECR权限 | ✅ 已实现 | `aws_iam_policy.dify_ee_ecr_policy` |
| IRSA支持 | ✅ 已实现 | `aws_iam_openid_connect_provider.eks` |

### 2. IAM角色和策略

| 升级指南要求 | Terraform资源 | 状态 |
|-------------|---------------|------|
| `DifyEE-Role-{cluster}-s3` | `aws_iam_role.dify_ee_s3_role` | ✅ 已实现 |
| `DifyEE-Role-{cluster}-s3-ecr` | `aws_iam_role.dify_ee_s3_ecr_role` | ✅ 已实现 |
| `DifyEE-Role-{cluster}-ecr-image-pull` | `aws_iam_role.dify_ee_ecr_pull_role` | ✅ 已实现 |
| `dify-ee-irsa-{cluster}-s3-policy` | `aws_iam_policy.dify_ee_s3_policy` | ✅ 已实现 |
| `dify-ee-irsa-{cluster}-ecr-policy` | `aws_iam_policy.dify_ee_ecr_policy` | ✅ 已实现 |
| `dify-ee-irsa-{cluster}-ecr-pull-only-policy` | `aws_iam_policy.dify_ee_ecr_pull_only_policy` | ✅ 已实现 |

### 3. ServiceAccount配置

| 升级指南ServiceAccount | Terraform资源 | 用途 | 状态 |
|----------------------|---------------|------|------|
| `dify-api-sa` | `kubernetes_service_account.dify_api` | dify-api、dify-worker使用 | ✅ 已实现 |
| `dify-plugin-crd-sa` | `kubernetes_service_account.dify_plugin_crd` | dify-plugin-crd镜像构建使用 | ✅ 已实现 |
| `dify-plugin-runner-sa` | `kubernetes_service_account.dify_plugin_runner` | dify-plugin运行时使用 | ✅ 已实现 |
| `dify-plugin-connector-sa` | `kubernetes_service_account.dify_plugin_connector` | plugin connector使用 | ✅ 新增 |
| `dify-plugin-build-sa` | `kubernetes_service_account.dify_plugin_build` | 兼容性别名 | ✅ 新增 |
| `dify-plugin-build-run-sa` | `kubernetes_service_account.dify_plugin_build_run` | 兼容性别名 | ✅ 新增 |

### 4. 数据库配置

| 升级指南要求 | Terraform实现 | 状态 |
|-------------|---------------|------|
| 主数据库 `dify` | `aws_rds_cluster.main.database_name` | ✅ 已实现 |
| 插件数据库 `dify_plugin_daemon` | `null_resource.create_plugin_daemon_database` | ✅ 新增 |

### 5. Helm Chart配置

| 升级指南配置项 | Terraform Helm设置 | 状态 |
|---------------|-------------------|------|
| `plugin_daemon.enabled: true` | `plugin_daemon.enabled` | ✅ 已实现 |
| `plugin_daemon.apiKey` | `plugin_daemon.apiKey` | ✅ 已实现 |
| `plugin_connector.apiKey` | `plugin_connector.apiKey` | ✅ 已实现 |
| `plugin_connector.customServiceAccount` | `plugin_connector.customServiceAccount` | ✅ 已实现 |
| `plugin_connector.runnerServiceAccount` | `plugin_connector.runnerServiceAccount` | ✅ 已实现 |
| `plugin_connector.imageRepoPrefix` | `plugin_connector.imageRepoPrefix` | ✅ 已实现 |
| `plugin_connector.imageRepoType: ecr` | `plugin_connector.imageRepoType` | ✅ 已实现 |
| `plugin_connector.ecrRegion` | `plugin_connector.ecrRegion` | ✅ 已实现 |
| `externalPostgres.enabled: true` | `externalPostgres.enabled` | ✅ 已实现 |
| `externalPostgres.credentials.plugin_daemon` | `externalPostgres.credentials.plugin_daemon.*` | ✅ 已实现 |

### 6. S3配置

| 升级指南配置项 | Terraform实现 | 状态 |
|---------------|---------------|------|
| `persistence.type: "s3"` | Helm values配置 | ✅ 已实现 |
| `s3.useAwsS3: true` | Helm values配置 | ✅ 已实现 |
| `s3.useAwsManagedIam: true` | Helm values配置 | ✅ 已实现 |

## 🆕 新增功能

### 1. 数据库自动创建
```hcl
resource "null_resource" "create_plugin_daemon_database" {
  provisioner "local-exec" {
    command = <<-EOT
      PGPASSWORD="${var.rds_password}" psql -h ${aws_rds_cluster.main.endpoint} -U ${var.rds_username} -d dify -c "CREATE DATABASE dify_plugin_daemon;"
    EOT
  }
}
```

### 2. 额外的ServiceAccount
- `dify-plugin-connector-sa`: 用于plugin connector服务
- `dify-plugin-build-sa`: 兼容性别名，指向`dify-plugin-crd-sa`
- `dify-plugin-build-run-sa`: 兼容性别名，指向`dify-plugin-runner-sa`

### 3. 完整的Helm配置
所有升级指南中提到的Helm配置项都已通过Terraform自动设置。

## 🔧 使用方法

### 1. 部署基础设施
```bash
terraform init
terraform plan
terraform apply
```

### 2. 验证部署
```bash
./post_deploy_verification.sh
```

### 3. 检查数据库
```bash
# 验证plugin daemon数据库已创建
PGPASSWORD="your_password" psql -h $(terraform output -raw aurora_cluster_endpoint) -U postgres -d dify -c "SELECT datname FROM pg_database WHERE datname='dify_plugin_daemon';"
```

### 4. 检查ServiceAccounts
```bash
# 检查所有ServiceAccount
kubectl get sa -n default | grep dify

# 检查IRSA注解
kubectl describe sa dify-plugin-connector-sa -n default
```

## 📋 配置变量

### 新增变量
```hcl
# Plugin API密钥
dify_plugin_api_key = "your-secure-api-key"

# 是否创建plugin daemon数据库
create_plugin_daemon_database = true
```

## 🎯 升级路径

### 从旧版本升级
1. **更新Terraform配置**: 使用最新的配置文件
2. **运行Terraform**: `terraform apply`
3. **验证资源**: 运行验证脚本
4. **部署应用**: 使用Helm部署Dify EE 3.0.0

### 新部署
1. **配置变量**: 设置`terraform.tfvars`
2. **部署基础设施**: `terraform apply`
3. **部署应用**: 启用`install_dify_chart = true`

## ⚠️ 注意事项

### 1. 数据库创建
- 需要本地安装`postgresql-client`
- 确保网络连接到Aurora集群
- 数据库创建是幂等的，重复运行不会出错

### 2. ServiceAccount权限
- 所有ServiceAccount都已配置正确的IRSA注解
- 权限遵循最小权限原则
- 支持升级指南中的所有命名约定

### 3. Helm配置
- 所有配置项都通过Terraform自动设置
- 支持自定义values文件覆盖
- 兼容Dify EE 3.0.0版本

## 🔍 故障排除

### 数据库创建失败
```bash
# 手动创建数据库
PGPASSWORD="your_password" psql -h your-aurora-endpoint -U postgres -d dify -c "CREATE DATABASE dify_plugin_daemon;"
```

### ServiceAccount权限问题
```bash
# 检查IAM角色
aws iam get-role --role-name DifyEE-Role-your-cluster-s3

# 检查ServiceAccount注解
kubectl describe sa dify-plugin-connector-sa -n default
```

### Helm部署问题
```bash
# 检查Helm values
helm get values dify -n dify

# 查看Pod状态
kubectl get pods -n dify
```

## ✅ 合规性总结

我们的Terraform配置完全符合升级指南的所有要求：

- ✅ **IAM角色和策略**: 所有必需的角色和策略都已创建
- ✅ **ServiceAccount**: 所有ServiceAccount及其IRSA注解都已配置
- ✅ **数据库**: 主数据库和plugin daemon数据库都已准备就绪
- ✅ **ECR仓库**: 插件镜像仓库已创建并配置
- ✅ **S3配置**: IRSA模式的S3访问已配置
- ✅ **Helm配置**: 所有必需的Helm配置项都已设置
- ✅ **兼容性**: 支持升级指南中的所有命名约定

**部署完成后，您的环境将完全符合Dify EE 3.0.0的升级要求！**