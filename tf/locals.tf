# ──────────────── 全局 Locals 配置 ────────────────
# 包含所有文件共用的本地变量

locals {
  # 根据区域自动选择ARN格式和配置
  is_china_region = contains(["cn-north-1", "cn-northwest-1"], var.aws_region)
  arn_prefix      = local.is_china_region ? "arn:aws-cn" : "arn:aws"
}