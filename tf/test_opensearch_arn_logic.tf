# 测试文件：验证 OpenSearch ARN 逻辑
# 这个文件仅用于测试，实际部署时可以删除

# 测试不同区域的 OpenSearch ARN 格式
locals {
  test_regions = ["us-east-1", "us-west-2", "cn-north-1", "cn-northwest-1", "eu-west-1"]
  test_account_id = "123456789012"
  test_cluster_name = "test-cluster"
  
  opensearch_arn_test_results = {
    for region in local.test_regions : region => {
      is_china_region = contains(["cn-north-1", "cn-northwest-1"], region)
      arn_prefix      = contains(["cn-north-1", "cn-northwest-1"], region) ? "arn:aws-cn" : "arn:aws"
      opensearch_arn  = "${contains(["cn-north-1", "cn-northwest-1"], region) ? "arn:aws-cn" : "arn:aws"}:es:${region}:${local.test_account_id}:domain/${local.test_cluster_name}-opensearch/*"
    }
  }
}

# 输出测试结果
output "opensearch_arn_test_results" {
  description = "测试不同区域的 OpenSearch ARN 格式"
  value       = local.opensearch_arn_test_results
}