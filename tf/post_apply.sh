#!/bin/bash

# Terraform Apply后置处理脚本
# 自动生成Dify部署所需的配置文件

set -e

echo "=========================================="
echo "  Terraform Apply 后置处理"
echo "=========================================="

# 检查terraform状态
if [ ! -f "terraform.tfstate" ]; then
    echo "错误: 未找到terraform.tfstate文件"
    exit 1
fi

echo "✅ Terraform状态文件存在"

# 生成输出日志 (out.log)
echo "📝 生成输出日志..."
{
    echo "# Terraform输出日志"
    echo "# 生成时间: $(date)"
    echo "# ========================================"
    echo
    terraform output
    echo
    echo "# ========================================"
    echo "# 敏感信息"
    echo "# ========================================"
    echo
    # 从配置文件中提取密码
    if [ -f "rds.tf" ]; then
        RDS_PASSWORD=$(grep "master_password" rds.tf | sed 's/.*= *"\([^"]*\)".*/\1/' | head -1 || echo "DifyRdsPassword123!")
        echo "RDS_PASSWORD = \"$RDS_PASSWORD\""
    fi
    
    if [ -f "opensearch.tf" ]; then
        OPENSEARCH_PASSWORD=$(grep "master_password" opensearch.tf | sed 's/.*= *"\([^"]*\)".*/\1/' | head -1 || echo "DifyOpenSearch123!")
        echo "OPENSEARCH_PASSWORD = \"$OPENSEARCH_PASSWORD\""
    fi
    
} > out.log

chmod 600 out.log
echo "✅ 输出日志已生成: out.log"

# 运行配置生成脚本
if [ -f "generate_dify_config.sh" ]; then
    echo "🚀 运行Dify配置生成脚本..."
    ./generate_dify_config.sh
else
    echo "⚠️  未找到generate_dify_config.sh脚本"
fi

echo
echo "=========================================="
echo "  后置处理完成！"
echo "=========================================="
echo
echo "生成的文件:"
echo "  - out.log                      (Terraform输出日志)"
echo "  - dify_deployment_config_*.txt (Dify部署配置)"
echo "  - dify_values_*.yaml          (Helm Values文件)"
echo "  - deploy_dify_*.sh            (自动部署脚本)"
echo
echo "下一步操作:"
echo "  1. 检查生成的配置文件"
echo "  2. 修改域名和密钥"
echo "  3. 运行部署脚本或手动部署Dify"
echo