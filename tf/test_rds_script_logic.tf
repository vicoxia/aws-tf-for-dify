# 测试文件：验证 RDS 脚本选择逻辑
# 这个文件仅用于测试，实际部署时可以删除

# 输出当前的脚本选择逻辑
output "rds_script_selection_test" {
  description = "测试 RDS 数据库创建脚本选择逻辑"
  value = {
    current_region = var.aws_region
    is_china_region = local.is_china_region
    selected_script = local.is_china_region ? 
      "create_dify_databases_china.sh" : 
      "create_dify_databases_dataapi.sh"
    
    # 测试不同区域的结果
    test_scenarios = {
      "us-east-1" = {
        is_china = contains(["cn-north-1", "cn-northwest-1"], "us-east-1")
        script = contains(["cn-north-1", "cn-northwest-1"], "us-east-1") ? 
          "create_dify_databases_china.sh" : 
          "create_dify_databases_dataapi.sh"
      }
      "cn-north-1" = {
        is_china = contains(["cn-north-1", "cn-northwest-1"], "cn-north-1")
        script = contains(["cn-north-1", "cn-northwest-1"], "cn-north-1") ? 
          "create_dify_databases_china.sh" : 
          "create_dify_databases_dataapi.sh"
      }
      "cn-northwest-1" = {
        is_china = contains(["cn-north-1", "cn-northwest-1"], "cn-northwest-1")
        script = contains(["cn-north-1", "cn-northwest-1"], "cn-northwest-1") ? 
          "create_dify_databases_china.sh" : 
          "create_dify_databases_dataapi.sh"
      }
    }
  }
}