# Terraform State 管理方案使用说明

## 前提条件

1. 确保已安装 AWS CLI 并配置好凭证
2. 确保已安装 Terraform

## 初始化步骤

### 1. 首次设置

首先需要创建 S3 bucket 和 DynamoDB 表。由于这些资源是用于存储状态文件的，我们需要先使用本地状态文件创建它们：

```bash
# 临时注释掉 backend.tf 中的 backend 配置
# 可以重命名文件为 backend.tf.bak 或在文件中注释相关代码

# 初始化项目
terraform init

# 创建状态管理所需的资源
terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_locks
```

### 2. 迁移到远程状态

在 S3 bucket 和 DynamoDB 表创建完成后：

```bash
# 恢复 backend.tf 的配置

# 重新初始化以启用远程状态存储
terraform init

# 系统会提示是否要将本地状态复制到远程，选择"yes"
```

## 日常使用

配置完成后，团队成员只需要：

1. 克隆代码仓库
2. 运行 `terraform init` 初始化项目
3. 正常使用 terraform 命令，如：
   - `terraform plan` 查看变更计划
   - `terraform apply` 应用变更
   - `terraform destroy` 清理资源

## 状态管理特性

1. **并发保护**：
   - DynamoDB 提供状态锁定，防止并发操作
   - 如果有人正在运行 terraform，其他人的操作会被阻止

2. **版本控制**：
   - S3 bucket 启用了版本控制
   - 可以回溯查看历史状态
   - 可以在必要时回滚到之前的状态

3. **安全性**：
   - 状态文件在 S3 中使用 AES256 加密存储
   - S3 bucket 禁用了所有公共访问
   - 需要适当的 AWS IAM 权限才能访问

## 注意事项

1. 确保 AWS 凭证有足够权限访问 S3 和 DynamoDB
2. 不要手动删除或修改 S3 中的状态文件
3. 如果状态锁定出现问题，可以在 DynamoDB 中手动删除锁定记录
4. 建议定期备份 S3 中的状态文件

## 所需的 IAM 权限

用户需要以下最小权限集：

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws-cn:s3:::test-eks-cluster-terraform-state",
                "arn:aws-cn:s3:::test-eks-cluster-terraform-state/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem"
            ],
            "Resource": "arn:aws-cn:dynamodb:cn-north-1:*:table/test-eks-cluster-terraform-locks"
        }
    ]
}
```

## 故障排除

1. **状态锁定问题**：
   如果 terraform 操作被中断，可能需要手动解锁：
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

2. **状态文件损坏**：
   可以从 S3 版本历史中恢复之前的状态文件

3. **权限问题**：
   - 检查 AWS 凭证配置
   - 验证 IAM 权限是否正确
   - 确认 S3 bucket 和 DynamoDB 表的访问策略
