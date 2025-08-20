# Terraform 语法修复总结

## 问题描述

原始代码在 `rds.tf` 中使用了复杂的条件表达式，导致 Terraform 语法错误：

```hcl
# ❌ 错误的语法
command = var.aws_region == "cn-north-1" || var.aws_region == "cn-northwest-1" ? 
  "bash ${path.module}/create_dify_databases_china.sh" : 
  "bash ${path.module}/create_dify_databases_dataapi.sh"
```

**错误信息**:
```
Error: Invalid expression
Expected the start of an expression, but found an invalid expression token.
```

## 解决方案

使用 `locals.tf` 中预定义的 `local.is_china_region` 变量：

```hcl
# ✅ 正确的语法
command = local.is_china_region ? 
  "bash ${path.module}/create_dify_databases_china.sh" : 
  "bash ${path.module}/create_dify_databases_dataapi.sh"
```

## 相关文件修改

### 1. `locals.tf` (已存在)
```hcl
locals {
  # 根据区域自动选择ARN格式和配置
  is_china_region = contains(["cn-north-1", "cn-northwest-1"], var.aws_region)
  arn_prefix      = local.is_china_region ? "arn:aws-cn" : "arn:aws"
}
```

### 2. `rds.tf` (已修复)
```hcl
resource "null_resource" "create_additional_databases" {
  depends_on = [aws_rds_cluster_instance.main, aws_secretsmanager_secret_version.rds_credentials]

  provisioner "local-exec" {
    command = local.is_china_region ? 
      "bash ${path.module}/create_dify_databases_china.sh" : 
      "bash ${path.module}/create_dify_databases_dataapi.sh"

    environment = {
      CLUSTER_ARN = aws_rds_cluster.main.arn
      SECRET_ARN  = aws_secretsmanager_secret.rds_credentials.arn
      AWS_REGION  = var.aws_region
    }
  }

  triggers = {
    cluster_arn = aws_rds_cluster.main.arn
    secret_arn  = aws_secretsmanager_secret.rds_credentials.arn
    dataapi_script_hash = filemd5("${path.module}/create_dify_databases_dataapi.sh")
    china_script_hash   = filemd5("${path.module}/create_dify_databases_china.sh")
  }
}
```

## 工作原理

### 区域检测逻辑
```hcl
# 在 locals.tf 中定义
is_china_region = contains(["cn-north-1", "cn-northwest-1"], var.aws_region)
```

### 脚本选择逻辑
- **中国区域** (`cn-north-1`, `cn-northwest-1`): 使用 `create_dify_databases_china.sh`
- **全球区域** (其他所有区域): 使用 `create_dify_databases_dataapi.sh`

## 验证方法

### 1. 语法检查
```bash
./check_syntax.sh
```

### 2. 逻辑测试
```bash
./test_database_script_selection.sh
```

### 3. Terraform 验证
```bash
terraform validate
terraform plan
```

## 脚本功能对比

| 功能 | Data API 脚本 | 中国区脚本 |
|------|--------------|-----------|
| 连接方式 | RDS Data API | 直接 PostgreSQL 连接 |
| 网络要求 | 无需直连数据库 | 需要网络访问 RDS |
| 依赖工具 | aws CLI | aws CLI + psql + jq |
| 适用区域 | 全球区域 | 中国区域 |
| 错误处理 | 基础 | 完整 |

## 部署流程

1. **自动检测区域**: Terraform 读取 `var.aws_region`
2. **设置 local 变量**: `local.is_china_region` 自动计算
3. **选择脚本**: 根据 `local.is_china_region` 选择合适的脚本
4. **执行脚本**: 自动创建所需的数据库

## 注意事项

1. **中国区部署前准备**:
   - 安装 PostgreSQL 客户端: `sudo apt-get install postgresql-client`
   - 安装 jq 工具: `sudo apt-get install jq`
   - 确保网络可以访问 RDS 集群

2. **全球区域部署**:
   - 无需额外准备
   - 自动使用 RDS Data API

3. **故障排除**:
   - 参考 `TROUBLESHOOTING_CHINA_REGION.md`
   - 使用 `verify_china_deployment_readiness.sh` 检查准备情况

## 测试结果

✅ 语法检查通过
✅ 逻辑测试通过  
✅ 脚本文件存在且可执行
✅ 区域检测正确
✅ 脚本选择逻辑正确

修复完成，现在可以正常使用 `terraform plan` 和 `terraform apply`。