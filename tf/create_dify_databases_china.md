# 中国区数据库创建指南

## 问题说明

AWS 中国区不支持 RDS Data API，因此无法通过 Terraform 自动创建额外的数据库。需要手动创建以下数据库：

## 需要创建的数据库

1. `dify_enterprise` - Dify 企业版主数据库
2. `dify_audit` - 审计日志数据库  
3. `dify_plugin_daemon` - 插件守护进程数据库

## 手动创建步骤

### 1. 获取数据库连接信息

部署完成后，从 Terraform 输出获取连接信息：

```bash
terraform output rds_endpoint
terraform output rds_username
```

### 2. 获取数据库密码

从 AWS Secrets Manager 获取密码：

```bash
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw rds_credentials_secret_arn) \
  --region cn-northwest-1 \
  --query SecretString --output text | jq -r .password
```

### 3. 连接数据库

使用 psql 或其他 PostgreSQL 客户端连接：

```bash
psql -h <RDS_ENDPOINT> -U postgres -d postgres
```

### 4. 创建数据库

在 PostgreSQL 命令行中执行：

```sql
CREATE DATABASE "dify_enterprise";
CREATE DATABASE "dify_audit";  
CREATE DATABASE "dify_plugin_daemon";

-- 验证创建结果
\l
```

### 5. 验证创建结果

确认所有数据库都已创建成功：

```sql
SELECT datname FROM pg_database WHERE datname LIKE 'dify_%';
```

应该看到三个数据库：
- dify_enterprise
- dify_audit
- dify_plugin_daemon

## 自动化脚本（可选）

如果你有网络连接到 RDS，可以使用以下脚本：

```bash
#!/bin/bash

# 设置连接参数
export PGHOST=$(terraform output -raw rds_endpoint)
export PGUSER=postgres
export PGPASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw rds_credentials_secret_arn) \
  --region cn-northwest-1 \
  --query SecretString --output text | jq -r .password)

# 创建数据库
databases=("dify_enterprise" "dify_audit" "dify_plugin_daemon")

for db in "${databases[@]}"; do
    echo "创建数据库: $db"
    psql -d postgres -c "CREATE DATABASE \"$db\";" 2>/dev/null || echo "数据库 $db 可能已存在"
done

echo "数据库创建完成！"
```

## 注意事项

1. 确保你的网络可以访问 RDS 实例
2. 如果 RDS 在私有子网中，需要通过堡垒机或 VPN 连接
3. 数据库创建是一次性操作，重复执行不会有问题
4. 建议在 Dify 应用部署前完成数据库创建