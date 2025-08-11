#!/bin/bash

# Dify密码管理脚本
# 用于生成、存储和检索Dify部署中使用的所有密码

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORD_FILE="$SCRIPT_DIR/.dify_passwords"
ENCRYPTED_PASSWORD_FILE="$SCRIPT_DIR/.dify_passwords.enc"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    echo "Dify密码管理工具"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  generate    生成新的密码并保存"
    echo "  show        显示所有密码"
    echo "  export      导出环境变量"
    echo "  encrypt     加密密码文件"
    echo "  decrypt     解密密码文件"
    echo "  backup      备份密码到AWS Secrets Manager"
    echo "  restore     从AWS Secrets Manager恢复密码"
    echo "  rotate      轮换所有密码"
    echo "  help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 generate     # 生成新密码"
    echo "  $0 show         # 显示当前密码"
    echo "  $0 export       # 导出为环境变量"
}

generate_rds_password() {
    local length=${1:-24}
    local charset="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&*+-=?^_\`|~"
    local password=""
    
    for i in $(seq 1 $length); do
        password+="${charset:$((RANDOM % ${#charset})):1}"
    done
    
    echo "$password"
}

generate_passwords() {
    echo -e "${BLUE}🔐 生成Dify部署密码${NC}"
    echo "======================="
    
    # 生成时间戳
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 生成所有密码
    local rds_password=$(generate_rds_password 24)
    local opensearch_password=$(generate_rds_password 24)
    local app_secret_key=$(openssl rand -base64 42)
    local admin_api_secret_key_salt=$(openssl rand -base64 32)
    local sandbox_api_key=$(openssl rand -base64 32)
    local inner_api_key=$(openssl rand -base64 32)
    local plugin_api_key=$(openssl rand -base64 32)
    local plugin_inner_api_key="QaHbTe77CtuXmsfyhR7+vRjI/+XbV1AaFy691iy+kGDv2Jvy0/eAh8Y1"
    
    # 保存到文件
    cat > "$PASSWORD_FILE" << EOF
# Dify部署密码文件
# 生成时间: $timestamp
# 环境: \${TF_VAR_environment:-test}

# 数据库密码
TF_VAR_rds_username=postgres
TF_VAR_rds_password=$rds_password

# OpenSearch密码
TF_VAR_opensearch_admin_name=admin
TF_VAR_opensearch_password=$opensearch_password

# Dify应用密钥
TF_VAR_dify_app_secret_key=$app_secret_key
TF_VAR_dify_admin_api_secret_key_salt=$admin_api_secret_key_salt
TF_VAR_dify_sandbox_api_key=$sandbox_api_key
TF_VAR_dify_inner_api_key=$inner_api_key
TF_VAR_dify_plugin_api_key=$plugin_api_key
TF_VAR_dify_plugin_inner_api_key=$plugin_inner_api_key

# 生成信息
GENERATED_AT=$timestamp
GENERATED_BY=\$(whoami)
GENERATED_ON=\$(hostname)
EOF
    
    chmod 600 "$PASSWORD_FILE"
    echo -e "${GREEN}✅ 密码已生成并保存到: $PASSWORD_FILE${NC}"
    echo -e "${YELLOW}⚠️  请妥善保管此文件，建议加密存储${NC}"
}

show_passwords() {
    if [ ! -f "$PASSWORD_FILE" ]; then
        echo -e "${RED}❌ 密码文件不存在，请先运行: $0 generate${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔍 当前密码信息${NC}"
    echo "=================="
    
    # 显示生成信息
    if grep -q "GENERATED_AT" "$PASSWORD_FILE"; then
        echo "生成时间: $(grep GENERATED_AT "$PASSWORD_FILE" | cut -d'=' -f2)"
        echo "生成用户: $(grep GENERATED_BY "$PASSWORD_FILE" | cut -d'=' -f2)"
        echo "生成主机: $(grep GENERATED_ON "$PASSWORD_FILE" | cut -d'=' -f2)"
        echo ""
    fi
    
    # 显示密码（隐藏敏感部分）
    echo "数据库配置:"
    echo "  用户名: $(grep TF_VAR_rds_username "$PASSWORD_FILE" | cut -d'=' -f2)"
    echo "  密码: $(grep TF_VAR_rds_password "$PASSWORD_FILE" | cut -d'=' -f2 | sed 's/\(.\{4\}\).*/\1***/')"
    
    echo ""
    echo "OpenSearch配置:"
    echo "  用户名: $(grep TF_VAR_opensearch_admin_name "$PASSWORD_FILE" | cut -d'=' -f2)"
    echo "  密码: $(grep TF_VAR_opensearch_password "$PASSWORD_FILE" | cut -d'=' -f2 | sed 's/\(.\{4\}\).*/\1***/')"
    
    echo ""
    echo "Dify应用密钥:"
    echo "  App Secret: $(grep TF_VAR_dify_app_secret_key "$PASSWORD_FILE" | cut -d'=' -f2 | sed 's/\(.\{8\}\).*/\1***/')"
    echo "  Admin Salt: $(grep TF_VAR_dify_admin_api_secret_key_salt "$PASSWORD_FILE" | cut -d'=' -f2 | sed 's/\(.\{8\}\).*/\1***/')"
    echo "  Sandbox Key: $(grep TF_VAR_dify_sandbox_api_key "$PASSWORD_FILE" | cut -d'=' -f2 | sed 's/\(.\{8\}\).*/\1***/')"
    echo "  Inner API Key: $(grep TF_VAR_dify_inner_api_key "$PASSWORD_FILE" | cut -d'=' -f2 | sed 's/\(.\{8\}\).*/\1***/')"
    echo "  Plugin API Key: $(grep TF_VAR_dify_plugin_api_key "$PASSWORD_FILE" | cut -d'=' -f2 | sed 's/\(.\{8\}\).*/\1***/')"
    
    echo ""
    echo -e "${YELLOW}💡 要查看完整密码，请运行: $0 export${NC}"
}

export_passwords() {
    if [ ! -f "$PASSWORD_FILE" ]; then
        echo -e "${RED}❌ 密码文件不存在，请先运行: $0 generate${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📤 导出环境变量${NC}"
    echo "=================="
    echo ""
    echo "# 复制以下内容到您的shell中："
    echo ""
    
    # 导出所有TF_VAR变量
    grep "^TF_VAR_" "$PASSWORD_FILE" | while read line; do
        echo "export $line"
    done
    
    echo ""
    echo "# 或者直接source此文件："
    echo "source <($0 export-source)"
}

export_source() {
    if [ ! -f "$PASSWORD_FILE" ]; then
        echo "echo '❌ 密码文件不存在'"
        exit 1
    fi
    
    grep "^TF_VAR_" "$PASSWORD_FILE" | while read line; do
        echo "export $line"
    done
}

encrypt_passwords() {
    if [ ! -f "$PASSWORD_FILE" ]; then
        echo -e "${RED}❌ 密码文件不存在，请先运行: $0 generate${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔒 加密密码文件${NC}"
    echo "================"
    
    read -s -p "请输入加密密码: " encrypt_pass
    echo ""
    
    openssl enc -aes-256-cbc -salt -in "$PASSWORD_FILE" -out "$ENCRYPTED_PASSWORD_FILE" -pass pass:"$encrypt_pass"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 密码文件已加密: $ENCRYPTED_PASSWORD_FILE${NC}"
        echo -e "${YELLOW}⚠️  建议删除明文文件: rm $PASSWORD_FILE${NC}"
    else
        echo -e "${RED}❌ 加密失败${NC}"
        exit 1
    fi
}

decrypt_passwords() {
    if [ ! -f "$ENCRYPTED_PASSWORD_FILE" ]; then
        echo -e "${RED}❌ 加密密码文件不存在${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔓 解密密码文件${NC}"
    echo "================"
    
    read -s -p "请输入解密密码: " decrypt_pass
    echo ""
    
    openssl enc -aes-256-cbc -d -in "$ENCRYPTED_PASSWORD_FILE" -out "$PASSWORD_FILE" -pass pass:"$decrypt_pass"
    
    if [ $? -eq 0 ]; then
        chmod 600 "$PASSWORD_FILE"
        echo -e "${GREEN}✅ 密码文件已解密: $PASSWORD_FILE${NC}"
    else
        echo -e "${RED}❌ 解密失败，请检查密码${NC}"
        exit 1
    fi
}

backup_to_secrets_manager() {
    if [ ! -f "$PASSWORD_FILE" ]; then
        echo -e "${RED}❌ 密码文件不存在，请先运行: $0 generate${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}☁️  备份到AWS Secrets Manager${NC}"
    echo "=========================="
    
    local environment=${TF_VAR_environment:-test}
    local region=${TF_VAR_aws_region:-us-east-1}
    
    # 创建JSON格式的密码
    local secrets_json=$(cat << EOF
{
  "rds_username": "$(grep TF_VAR_rds_username "$PASSWORD_FILE" | cut -d'=' -f2)",
  "rds_password": "$(grep TF_VAR_rds_password "$PASSWORD_FILE" | cut -d'=' -f2)",
  "opensearch_admin_name": "$(grep TF_VAR_opensearch_admin_name "$PASSWORD_FILE" | cut -d'=' -f2)",
  "opensearch_password": "$(grep TF_VAR_opensearch_password "$PASSWORD_FILE" | cut -d'=' -f2)",
  "dify_app_secret_key": "$(grep TF_VAR_dify_app_secret_key "$PASSWORD_FILE" | cut -d'=' -f2)",
  "dify_admin_api_secret_key_salt": "$(grep TF_VAR_dify_admin_api_secret_key_salt "$PASSWORD_FILE" | cut -d'=' -f2)",
  "dify_sandbox_api_key": "$(grep TF_VAR_dify_sandbox_api_key "$PASSWORD_FILE" | cut -d'=' -f2)",
  "dify_inner_api_key": "$(grep TF_VAR_dify_inner_api_key "$PASSWORD_FILE" | cut -d'=' -f2)",
  "dify_plugin_api_key": "$(grep TF_VAR_dify_plugin_api_key "$PASSWORD_FILE" | cut -d'=' -f2)",
  "dify_plugin_inner_api_key": "$(grep TF_VAR_dify_plugin_inner_api_key "$PASSWORD_FILE" | cut -d'=' -f2)",
  "generated_at": "$(grep GENERATED_AT "$PASSWORD_FILE" | cut -d'=' -f2)",
  "generated_by": "$(grep GENERATED_BY "$PASSWORD_FILE" | cut -d'=' -f2)"
}
EOF
)
    
    # 上传到Secrets Manager
    aws secretsmanager create-secret \
        --name "dify-$environment-all-passwords" \
        --description "All passwords for Dify $environment deployment" \
        --secret-string "$secrets_json" \
        --region "$region" 2>/dev/null || \
    aws secretsmanager update-secret \
        --secret-id "dify-$environment-all-passwords" \
        --secret-string "$secrets_json" \
        --region "$region"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 密码已备份到AWS Secrets Manager${NC}"
        echo "Secret名称: dify-$environment-all-passwords"
        echo "区域: $region"
    else
        echo -e "${RED}❌ 备份失败，请检查AWS权限${NC}"
        exit 1
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        generate)
            generate_passwords
            ;;
        show)
            show_passwords
            ;;
        export)
            export_passwords
            ;;
        export-source)
            export_source
            ;;
        encrypt)
            encrypt_passwords
            ;;
        decrypt)
            decrypt_passwords
            ;;
        backup)
            backup_to_secrets_manager
            ;;
        rotate)
            echo -e "${YELLOW}🔄 轮换密码${NC}"
            generate_passwords
            backup_to_secrets_manager
            ;;
        help|*)
            show_help
            ;;
    esac
}

main "$@"