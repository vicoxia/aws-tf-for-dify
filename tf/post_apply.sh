#!/bin/bash

# Terraform Apply后置处理脚本
# 自动生成Dify部署所需的配置文件

set -e


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

    echo
    echo "# ========================================"
    echo "# IRSA Role ARNs (for Helm values 注解)"
    echo "# ========================================"
    S3_ROLE_ARN=$(terraform output -raw dify_ee_s3_role_arn 2>/dev/null || echo "N/A")
    S3_ECR_ROLE_ARN=$(terraform output -raw dify_ee_s3_ecr_role_arn 2>/dev/null || echo "N/A")
    ECR_PULL_ROLE_ARN=$(terraform output -raw dify_ee_ecr_pull_role_arn 2>/dev/null || echo "N/A")
    echo "DIFY_EE_S3_ROLE_ARN = \"$S3_ROLE_ARN\""
    echo "DIFY_EE_S3_ECR_ROLE_ARN = \"$S3_ECR_ROLE_ARN\""
    echo "DIFY_EE_ECR_PULL_ROLE_ARN = \"$ECR_PULL_ROLE_ARN\""
    
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

echo "生成的文件:"
echo "  - out.log                      (Terraform输出日志)"
echo "  - dify_deployment_config_*.txt (Dify部署配置)"
echo "  - dify_values_*.yaml          (Helm Values文件)"
echo "  - deploy_dify_*.sh            (自动部署脚本)"
echo
echo "下一步操作:"
echo "  1. 检查生成的文件，并形成 values.yaml "
echo "  2. 修改 values.yaml 中的域名和密钥"
echo "  3. 运行 helm upgrade -i dify -f values.yaml dify/dify -n dify 部署 dify （请注意安装在 dify namespace 而非 default)"
echo

# 直接在控制台打印 IRSA 角色 ARN，方便复制到 values.yaml
echo "# ========================================"
echo "🔑 IRSA Role ARNs (复制到 Helm values 中的 serviceAccountAnnotations):"
S3_ROLE_ARN=$(terraform output -raw dify_ee_s3_role_arn 2>/dev/null || echo "N/A")
S3_ECR_ROLE_ARN=$(terraform output -raw dify_ee_s3_ecr_role_arn 2>/dev/null || echo "N/A")
ECR_PULL_ROLE_ARN=$(terraform output -raw dify_ee_ecr_pull_role_arn 2>/dev/null || echo "N/A")
echo "  - API/Worker (S3-only):           $S3_ROLE_ARN"
echo "  - Plugin CRD/Connector (S3+ECR):  $S3_ECR_ROLE_ARN"
echo "  - Plugin Runner (ECR Pull Only):  $ECR_PULL_ROLE_ARN"
echo "# ========================================"