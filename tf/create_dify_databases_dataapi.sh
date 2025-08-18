#!/bin/bash

# Dify Enterprise Database Creation Script (Using RDS Data API)
# This script uses the RDS Data API to create additional databases required for Dify Enterprise Edition.
# No direct network connection to the database is needed; operations are performed via AWS API calls.
# This script will be automatically executed during the terraform build process, no manual execution is required, but you can run it manually if needed.

set -e  # 遇到错误立即退出


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}


check_env_vars() {
    print_info "检查环境变量..."
    
    required_vars=("CLUSTER_ARN" "SECRET_ARN" "AWS_REGION")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "环境变量 $var 未设置"
            exit 1
        fi
    done
    
    print_info "环境变量检查完成"
}

# 检查AWS CLI和权限
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI未安装"
        exit 1
    fi
    
    # 检查AWS凭证
    if ! aws sts get-caller-identity &>/dev/null; then
        print_error "AWS凭证未配置或无效"
        exit 1
    fi
    
    print_info "AWS CLI检查完成"
}

# 等待Aurora集群可用
wait_for_cluster() {
    print_info "等待Aurora集群可用..."
    
    max_attempts=60 # 最多等待60次，每次30秒，总计最多等待约30分钟
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        cluster_status=$(aws rds describe-db-clusters \
            --region "$AWS_REGION" \
            --db-cluster-identifier "${CLUSTER_ARN##*/}" \
            --query 'DBClusters[0].Status' \
            --output text 2>/dev/null || echo "not-found")
        
        if [ "$cluster_status" = "available" ]; then
            print_info "Aurora集群状态: 可用"
            return 0
        else
            print_warning "Aurora集群状态: $cluster_status，等待中... ($attempt/$max_attempts)"
            sleep 30
            ((attempt++))
        fi
    done
    
    print_error "Aurora集群等待超时"
    exit 1
}

# 使用RDS Data API执行SQL
execute_sql() {
    local sql_statement="$1"
    local database_name="${2:-postgres}"
    
    print_info "执行SQL: $sql_statement"
    
    local result
    result=$(aws rds-data execute-statement \
        --region "$AWS_REGION" \
        --resource-arn "$CLUSTER_ARN" \
        --secret-arn "$SECRET_ARN" \
        --database "$database_name" \
        --sql "$sql_statement" \
        --output json 2>&1)
    
    if [ $? -eq 0 ]; then
        print_info "SQL执行成功"
        return 0
    else
        print_error "SQL执行失败: $result"
        return 1
    fi
}

# 检查数据库是否存在
check_database_exists() {
    local db_name="$1"
    
    local sql="SELECT 1 FROM pg_database WHERE datname = '$db_name';"
    
    local result
    result=$(aws rds-data execute-statement \
        --region "$AWS_REGION" \
        --resource-arn "$CLUSTER_ARN" \
        --secret-arn "$SECRET_ARN" \
        --database "postgres" \
        --sql "$sql" \
        --output json 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # 检查返回的records数组是否有数据
        local record_count
        record_count=$(echo "$result" | jq '.records | length')
        
        if [ "$record_count" -gt 0 ]; then
            return 0  # 数据库存在
        else
            return 1  # 数据库不存在
        fi
    else
        return 1  # 查询失败，假设数据库不存在
    fi
}

# 创建数据库函数
create_database_if_not_exists() {
    local db_name="$1"
    
    print_info "检查数据库: $db_name"
    
    if check_database_exists "$db_name"; then
        print_warning "数据库 $db_name 已存在，跳过创建"
        return 0
    fi
    
    print_info "创建数据库: $db_name"
    
    local sql="CREATE DATABASE \"$db_name\";"
    
    if execute_sql "$sql" "postgres"; then
        print_info "数据库 $db_name 创建成功"
        return 0
    else
        print_error "数据库 $db_name 创建失败"
        return 1
    fi
}

# 主函数
main() {
    print_info "开始创建Dify企业版数据库（使用RDS Data API）..."
    
    # 检查环境变量
    check_env_vars
    
    # 检查AWS CLI和权限
    check_aws_cli
    
    # 等待集群可用
    wait_for_cluster
    
    # 创建所需的数据库
    databases=("dify_enterprise" "dify_audit" "dify_plugin_daemon")
    
    failed_databases=()
    
    for db in "${databases[@]}"; do
        if ! create_database_if_not_exists "$db"; then
            failed_databases+=("$db")
        fi
    done
    
    if [ ${#failed_databases[@]} -eq 0 ]; then
        print_info "所有数据库创建完成！"
        
        # 输出连接信息
        print_info "数据库连接信息："
        echo "  集群ARN: $CLUSTER_ARN"
        echo "  密钥ARN: $SECRET_ARN"
        echo "  区域: $AWS_REGION"
        echo "  已创建的数据库:"
        for db in "${databases[@]}"; do
            echo "    - $db"
        done
    else
        print_error "以下数据库创建失败: ${failed_databases[*]}"
        exit 1
    fi
}

# 脚本帮助信息
show_help() {
    cat << EOF
Dify Enterprise Database Creation Script (RDS Data API)

用法:
    $0 [选项]

环境变量:
    CLUSTER_ARN  - Aurora集群的ARN (必需)
    SECRET_ARN   - Secrets Manager中存储数据库凭证的ARN (必需)
    AWS_REGION   - AWS区域 (必需)

示例:
    export CLUSTER_ARN="arn:aws:rds:us-east-2:123456789012:cluster:my-cluster"
    export SECRET_ARN="arn:aws:secretsmanager:us-east-2:123456789012:secret:rds-db-credentials/cluster-123456/postgres"
    export AWS_REGION="us-east-2"
    $0

注意:
    - 此脚本使用RDS Data API，无需网络连接到数据库
    - 需要AWS CLI已配置且有适当权限
    - Aurora集群必须启用Data API (enable_http_endpoint = true)
    - 数据库凭证必须存储在AWS Secrets Manager中

选项:
    -h, --help   显示此帮助信息

EOF
}

# 处理命令行参数
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "未知选项: $1"
        show_help
        exit 1
        ;;
esac
