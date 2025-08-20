#!/bin/bash

echo "=== 测试数据库脚本选择逻辑 ==="

# 测试不同区域的脚本选择
regions=("us-east-1" "us-west-2" "cn-north-1" "cn-northwest-1" "eu-west-1")

for region in "${regions[@]}"; do
    echo ""
    echo "测试区域: $region"
    
    # 模拟 Terraform 的条件逻辑
    if [[ "$region" == "cn-north-1" || "$region" == "cn-northwest-1" ]]; then
        script="create_dify_databases_china.sh"
        echo "  ✅ 中国区域 -> 使用脚本: $script"
    else
        script="create_dify_databases_dataapi.sh"
        echo "  ✅ 全球区域 -> 使用脚本: $script"
    fi
    
    # 检查脚本是否存在
    if [ -f "$script" ]; then
        echo "  ✅ 脚本文件存在"
        
        # 检查脚本是否可执行
        if [ -x "$script" ]; then
            echo "  ✅ 脚本可执行"
        else
            echo "  ⚠️  脚本不可执行，需要 chmod +x $script"
        fi
    else
        echo "  ❌ 脚本文件不存在: $script"
    fi
done

echo ""
echo "=== 验证脚本内容 ==="

# 检查中国区脚本的关键功能
if [ -f "create_dify_databases_china.sh" ]; then
    echo "检查中国区脚本功能..."
    
    if grep -q "psql" create_dify_databases_china.sh; then
        echo "  ✅ 包含 PostgreSQL 直连功能"
    else
        echo "  ❌ 缺少 PostgreSQL 直连功能"
    fi
    
    if grep -q "check_dependencies" create_dify_databases_china.sh; then
        echo "  ✅ 包含依赖检查功能"
    else
        echo "  ❌ 缺少依赖检查功能"
    fi
    
    if grep -q "dify_enterprise\|dify_audit\|dify_plugin_daemon" create_dify_databases_china.sh; then
        echo "  ✅ 包含所需数据库列表"
    else
        echo "  ❌ 缺少数据库列表"
    fi
fi

# 检查 Data API 脚本
if [ -f "create_dify_databases_dataapi.sh" ]; then
    echo ""
    echo "检查 Data API 脚本功能..."
    
    if grep -q "rds-data execute-statement" create_dify_databases_dataapi.sh; then
        echo "  ✅ 包含 RDS Data API 功能"
    else
        echo "  ❌ 缺少 RDS Data API 功能"
    fi
    
    if grep -q "is_china_region" create_dify_databases_dataapi.sh; then
        echo "  ✅ 包含中国区检测逻辑"
    else
        echo "  ❌ 缺少中国区检测逻辑"
    fi
fi

echo ""
echo "=== 建议 ==="
echo "1. 确保两个脚本都有执行权限："
echo "   chmod +x create_dify_databases_china.sh"
echo "   chmod +x create_dify_databases_dataapi.sh"
echo ""
echo "2. 在中国区部署前，确保具备以下条件："
echo "   - 安装了 PostgreSQL 客户端 (psql)"
echo "   - 安装了 jq 工具"
echo "   - 网络可以访问 RDS 集群"
echo ""
echo "3. 测试脚本功能："
echo "   ./create_dify_databases_china.sh --help"
echo "   ./create_dify_databases_dataapi.sh --help"