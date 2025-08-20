#!/bin/bash

# 中国区数据库设置指导脚本
# 此脚本帮助用户在中国区正确设置数据库

echo "=== 中国区 Dify 数据库设置指导 ==="
echo ""

# 检查是否为中国区
if [ -f "terraform.tfvars" ]; then
    REGION=$(grep "aws_region" terraform.tfvars | cut -d'"' -f2 2>/dev/null)
    if [[ "$REGION" == "cn-north-1" || "$REGION" == "cn-northwest-1" ]]; then
        echo "✅ 检测到中国区域: $REGION"
        IS_CHINA=true
    else
        echo "ℹ️  当前区域: $REGION (非中国区)"
        IS_CHINA=false
    fi
else
    echo "❌ 未找到 terraform.tfvars 文件"
    exit 1
fi

if [ "$IS_CHINA" != "true" ]; then
    echo "此指导仅适用于中国区域，您的区域数据库应该已自动创建。"
    exit 0
fi

echo ""
echo "由于网络限制，中国区的 Aurora 数据库无法从本地直接访问。"
echo "需要在 VPC 内部署一台 EC2 实例来执行数据库创建脚本。"
echo ""

# 获取部署信息
echo "=== 第一步：获取部署信息 ==="
echo ""
echo "请先完成 Terraform 部署："
echo "  terraform apply"
echo ""
echo "部署完成后，获取以下信息："
echo ""

if command -v terraform &> /dev/null; then
    echo "RDS 集群信息："
    if terraform output rds_endpoint &>/dev/null; then
        echo "  集群端点: $(terraform output -raw rds_endpoint 2>/dev/null || echo '请运行 terraform apply')"
        echo "  集群 ARN: $(terraform output -raw rds_cluster_arn 2>/dev/null || echo '请运行 terraform apply')"
        echo "  密钥 ARN: $(terraform output -raw rds_credentials_secret_arn 2>/dev/null || echo '请运行 terraform apply')"
    else
        echo "  请先运行 terraform apply 完成基础设施部署"
    fi
    echo ""
    
    echo "VPC 信息："
    if terraform output vpc_id &>/dev/null; then
        echo "  VPC ID: $(terraform output -raw vpc_id 2>/dev/null || echo '请运行 terraform apply')"
        echo "  私有子网: $(terraform output -json private_subnet_ids 2>/dev/null | jq -r '.[]' | head -1 || echo '请运行 terraform apply')"
    else
        echo "  请先运行 terraform apply 完成基础设施部署"
    fi
else
    echo "  集群端点: <从 AWS 控制台获取>"
    echo "  集群 ARN: <从 Terraform 输出获取>"
    echo "  密钥 ARN: <从 Terraform 输出获取>"
    echo "  VPC ID: <从 Terraform 输出获取>"
fi

echo ""
echo "=== 第二步：创建 EC2 实例 ==="
echo ""
echo "在 AWS 控制台创建 EC2 实例："
echo "  1. 选择 Amazon Linux 2023 AMI"
echo "  2. 实例类型：t3.micro (足够用于数据库操作)"
echo "  3. 网络设置："
echo "     - VPC: 选择与 Aurora 相同的 VPC"
echo "     - 子网: 选择私有子网（推荐）或公有子网"
echo "     - 安全组: 允许 SSH (22) 和访问 Aurora (5432)"
echo "  4. 密钥对: 选择或创建密钥对用于 SSH 访问"
echo ""

echo "安全组规则示例："
echo "  入站规则:"
echo "    - SSH (22): 0.0.0.0/0 或您的 IP"
echo "  出站规则:"
echo "    - PostgreSQL (5432): Aurora 安全组"
echo "    - HTTPS (443): 0.0.0.0/0 (用于 AWS API)"
echo ""

echo "=== 第三步：准备脚本和凭证 ==="
echo ""
echo "1. 将数据库创建脚本复制到 EC2："
echo "   scp -i your-key.pem create_dify_databases_china.sh ec2-user@<EC2-PUBLIC-IP>:~/"
echo ""
echo "2. SSH 连接到 EC2："
echo "   ssh -i your-key.pem ec2-user@<EC2-PUBLIC-IP>"
echo ""
echo "3. 在 EC2 上安装必要工具："
echo "   sudo yum update -y"
echo "   sudo yum install -y postgresql15 jq"
echo ""
echo "4. 配置 AWS CLI（如果尚未配置）："
echo "   aws configure"
echo "   # 输入您的 AWS Access Key ID 和 Secret Access Key"
echo ""

echo "=== 第四步：运行数据库创建脚本 ==="
echo ""
echo "在 EC2 实例上设置环境变量："

if command -v terraform &> /dev/null && terraform output rds_cluster_arn &>/dev/null; then
    echo "export CLUSTER_ARN=\"$(terraform output -raw rds_cluster_arn 2>/dev/null || echo 'arn:aws-cn:rds:REGION:ACCOUNT:cluster:CLUSTER-NAME')\""
    echo "export SECRET_ARN=\"$(terraform output -raw rds_credentials_secret_arn 2>/dev/null || echo 'arn:aws-cn:secretsmanager:REGION:ACCOUNT:secret:SECRET-NAME')\""
    echo "export AWS_REGION=\"$REGION\""
else
    echo "export CLUSTER_ARN=\"arn:aws-cn:rds:$REGION:YOUR-ACCOUNT:cluster:YOUR-CLUSTER-NAME\""
    echo "export SECRET_ARN=\"arn:aws-cn:secretsmanager:$REGION:YOUR-ACCOUNT:secret:YOUR-SECRET-NAME\""
    echo "export AWS_REGION=\"$REGION\""
fi

echo ""
echo "运行脚本："
echo "chmod +x create_dify_databases_china.sh"
echo "./create_dify_databases_china.sh"
echo ""

echo "=== 第五步：验证数据库创建 ==="
echo ""
echo "脚本成功运行后，应该会创建以下数据库："
echo "  - dify_enterprise"
echo "  - dify_audit"
echo "  - dify_plugin_daemon"
echo ""

echo "=== 故障排除 ==="
echo ""
echo "常见问题："
echo "1. 连接超时："
echo "   - 检查安全组配置"
echo "   - 确认 EC2 和 Aurora 在同一 VPC"
echo "   - 验证路由表配置"
echo ""
echo "2. 权限错误："
echo "   - 确认 AWS 凭证配置正确"
echo "   - 检查 IAM 权限（RDS、Secrets Manager）"
echo ""
echo "3. 工具缺失："
echo "   - 重新安装：sudo yum install -y postgresql15 jq"
echo ""

echo "=== 完成 ==="
echo ""
echo "数据库创建完成后，您可以继续部署 Dify 应用。"
echo "详细文档请参考：create_dify_databases_china.md"
echo ""
echo "如需帮助，请检查以下文档："
echo "  - create_dify_databases_china.md"
echo "  - CHINA_REGION_DEPLOYMENT_GUIDE.md"
echo "  - TROUBLESHOOTING_CHINA_REGION.md"