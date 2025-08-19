# Terraform Locals 结构说明

## 全局 Locals (locals.tf)

包含所有文件共用的本地变量：

```hcl
locals {
  # 根据区域自动选择ARN格式和配置
  is_china_region = contains(["cn-north-1", "cn-northwest-1"], var.aws_region)
  arn_prefix      = local.is_china_region ? "arn:aws-cn" : "arn:aws"
}
```

## 文件特定的 Locals

### eks.tf
- `cluster_subnets` - EKS 控制平面子网
- `node_subnets` - EKS 工作节点子网
- `iam_policy_arns` - IAM 策略 ARN 配置（使用全局 `arn_prefix`）
- `node_config` - 环境特定的节点配置

### helm.tf
- `default_helm_repositories` - 默认 Helm 仓库配置
- `helm_repositories` - 最终 Helm 仓库配置（支持用户自定义）

### opensearch.tf
- `opensearch_subnets` - OpenSearch 子网配置
- `opensearch_config` - 环境特定的 OpenSearch 配置

### vpc.tf
- `create_vpc` - 是否创建新 VPC
- `vpc_id` - VPC ID
- `availability_zones` - 可用区列表

### rds.tf
- `rds_subnets` - RDS 子网配置

### elasticache.tf
- `redis_subnets` - Redis 子网配置
- `redis_config` - 环境特定的 Redis 配置

### s3.tf
- `s3_storage_gb` - S3 存储容量配置

## 中国区自动适配

通过全局 locals 中的 `is_china_region` 和 `arn_prefix`，以下配置会自动适配：

1. **IAM 策略 ARN** (eks.tf)
   - 全球区域: `arn:aws:iam::aws:policy/...`
   - 中国区域: `arn:aws-cn:iam::aws:policy/...`

2. **OpenSearch ARN** (opensearch.tf)
   - 全球区域: `arn:aws:es:...`
   - 中国区域: `arn:aws-cn:es:...`

## 使用方法

只需在 `terraform.tfvars` 中设置正确的区域：

```hcl
# 中国区
aws_region = "cn-north-1"

# 全球区域
aws_region = "us-east-1"
```

系统会自动处理所有区域相关的配置差异。