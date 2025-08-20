# 测试文件：验证中国区域检测逻辑
# 这个文件仅用于测试，实际部署时可以删除

# 测试区域检测
output "china_region_detection_test" {
  description = "测试中国区域检测逻辑"
  value = {
    current_region = var.aws_region
    is_china_region = local.is_china_region
    arn_prefix = local.arn_prefix
    enable_http_endpoint = !local.is_china_region
    
    # 测试不同区域的结果
    test_results = {
      "us-east-1" = contains(["cn-north-1", "cn-northwest-1"], "us-east-1")
      "cn-north-1" = contains(["cn-north-1", "cn-northwest-1"], "cn-north-1")
      "cn-northwest-1" = contains(["cn-north-1", "cn-northwest-1"], "cn-northwest-1")
    }
  }
}