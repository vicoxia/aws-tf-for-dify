#!/bin/bash

# Dify Enterprise Database Creation Script for China Regions
# This script creates additional databases required for Dify Enterprise Edition in China regions
# where RDS Data API is not available. It uses direct PostgreSQL connection.

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

# 检查环境变量
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

# 检查必要工具
check_dependencies() {
    print_info "检查必要工具..."
    
    # 检查 AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI 未安装"
        exit 1
    fi
    
    # 检查 psql
    if ! command -v psql &> /dev/null; then
        print_error "PostgreSQL 客户端 (psql) 未安装"
        print_info "请安装 PostgreSQL 客户端："
        print_info "  Ubuntu/Debian: sudo apt-get install postgresql-client"
        print_info "  CentOS/RHEL: sudo yum install postgresql"
        print_info "  macOS: brew install postgresql"
        exit 1
    fi
    
    # 检查 jq
    if ! command -v jq &> /dev/null; then
        print_error "jq 未安装"
        print_info "请安装 jq："
        print_info "  Ubuntu/Debian: sudo apt-get install jq"
        print_info "  CentOS/RHEL: sudo yum install jq"
        print_info "  macOS: brew install jq"
        exit 1
    fi
    
    # 检查AWS凭证
    if ! aws sts get-caller-identity &>/dev/null; then
        print_error "AWS凭证未配置或无效"
        exit 1
    fi
    
    print_info "依赖检查完成"
}

# 等待Aurora集群可用
wait_for_cluster() {
    print_info "等待Aurora集群可用..."
    
    # 从 ARN 中提取集群标识符
    CLUSTER_ID=$(echo "$CLUSTER_ARN" | awk -F':' '{print $NF}')
    
    max_attempts=60 # 最多等待60次，每次30秒
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        cluster_status=$(aws rds describe-db-clusters \
            --region "$AWS_REGION" \
            --db-cluster-identifier "$CLUSTER_ID" \
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

# 获取数据库连接信息
get_connection_info() {
    print_info "获取数据库连接信息..."
    
    # 从 ARN 中提取集群标识符
    CLUSTER_ID=$(echo "$CLUSTER_ARN" | awk -F':' '{print $NF}')
    
    # 获取集群端点
    DB_ENDPOINT=$(aws rds describe-db-clusters \
        --region "$AWS_REGION" \
        --db-cluster-identifier "$CLUSTER_ID" \
        --query 'DBClusters[0].Endpoint' \
        --output text)
    
    if [ -z "$DB_ENDPOINT" ] || [ "$DB_ENDPOINT" = "None" ]; then
        print_error "无法获取数据库端点"
        exit 1
    fi
    
    # 获取数据库端口
    DB_PORT=$(aws rds describe-db-clusters \
        --region "$AWS_REGION" \
        --db-cluster-identifier "$CLUSTER_ID" \
        --query 'DBClusters[0].Port' \
        --output text)
    
    # 获取数据库凭证
    SECRET_VALUE=$(aws secretsmanager get-secret-value \
        --region "$AWS_REGION" \
        --secret-id "$SECRET_ARN" \
        --query SecretString \
        --output text)
    
    DB_USERNAME=$(echo "$SECRET_VALUE" | jq -r .username)
    DB_PASSWORD=$(echo "$SECRET_VALUE" | jq -r .password)
    
    if [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ]; then
        print_error "无法获取数据库凭证"
        exit 1
    fi
    
    print_info "数据库连接信息获取成功"
    print_info "  端点: $DB_ENDPOINT"
    print_info "  端口: $DB_PORT"
    print_info "  用户名: $DB_USERNAME"
}

# 测试数据库连接
test_connection() {
    print_info "测试数据库连接..."
    
    export PGPASSWORD="$DB_PASSWORD"
    
    if psql -h "$DB_ENDPOINT" -p "$DB_PORT" -U "$DB_USERNAME" -d postgres -c "SELECT 1;" &>/dev/null; then
        print_info "数据库连接测试成功"
    else
        print_error "数据库连接失败"
        print_error "请检查："
        print_error "  1. 网络连通性（VPC、安全组、路由）"
        print_error "  2. RDS 集群状态"
        print_error "  3. 数据库凭证"
        exit 1
    fi
}

# 检查数据库是否存在
check_database_exists() {
    local db_name="$1"
    
    export PGPASSWORD="$DB_PASSWORD"
    
    local result
    result=$(psql -h "$DB_ENDPOINT" -p "$DB_PORT" -U "$DB_USERNAME" -d postgres \
        -t -c "SELECT 1 FROM pg_database WHERE datname = '$db_name';" 2>/dev/null | xargs)
    
    if [ "$result" = "1" ]; then
        return 0  # 数据库存在
    else
        return 1  # 数据库不存在
    fi
}

# 创建数据库
create_database() {
    local db_name="$1"
    
    print_info "检查数据库: $db_name"
    
    if check_database_exists "$db_name"; then
        print_warning "数据库 $db_name 已存在，跳过创建"
        return 0
    fi
    
    print_info "创建数据库: $db_name"
    
    export PGPASSWORD="$DB_PASSWORD"
    
    if psql -h "$DB_ENDPOINT" -p "$DB_PORT" -U "$DB_USERNAME" -d postgres \
        -c "CREATE DATABASE \"$db_name\";" &>/dev/null; then
        print_info "数据库 $db_name 创建成功"
        return 0
    else
        print_error "数据库 $db_name 创建失败"
        return 1
    fi
}

# 验证数据库创建结果
verify_databases() {
    print_info "验证数据库创建结果..."
    
    export PGPASSWORD="$DB_PASSWORD"
    
    local databases
    databases=$(psql -h "$DB_ENDPOINT" -p "$DB_PORT" -U "$DB_USERNAME" -d postgres \
        -t -c "SELECT datname FROM pg_database WHERE datname LIKE 'dify_%' ORDER BY datname;" 2>/dev/null | xargs)
    
    if [ -n "$databases" ]; then
        print_info "已创建的 Dify 数据库："
        for db in $databases; do
            echo "    - $db"
        done
    else
        print_warning "未找到 Dify 相关数据库"
    fi
}

# 主函数
main() {
    print_info "开始创建Dify企业版数据库（中国区直连模式）..."
    
    # 检查环境变量
    check_env_vars
    
    # 检查依赖
    check_dependencies
    
    # 等待集群可用
    wait_for_cluster
    
    # 获取连接信息
    get_connection_info
    
    # 测试连接
    test_connection
    
    # 创建所需的数据库
    databases=("dify_enterprise" "dify_audit" "dify_plugin_daemon")
    
    failed_databases=()
    
    for db in "${databases[@]}"; do
        if ! create_database "$db"; then
            failed_databases+=("$db")
        fi
    done
    
    # 验证结果
    verify_databases
    
    if [ ${#failed_databases[@]} -eq 0 ]; then
        print_info "所有数据库创建完成！"
        
        # 输出连接信息
        print_info "数据库连接信息："
        echo "  集群端点: $DB_ENDPOINT"
        echo "  端口: $DB_PORT"
        echo "  用户名: $DB_USERNAME"
        echo "  区域: $AWS_REGION"
        echo "  已创建的数据库:"
        for db in "${databases[@]}"; do
            echo "    - $db"
        done
        
        print_info "注意：请妥善保管数据库连接信息"
    else
        print_error "以下数据库创建失败: ${failed_databases[*]}"
        print_error "请检查网络连接和权限设置"
        exit 1
    fi
}

# 脚本帮助信息
show_help() {
    cat << EOF
Dify Enterprise Database Creation Script for China Regions

用法:
    $0 [选项]

环境变量:
    CLUSTER_ARN  - Aurora集群的ARN (必需)
    SECRET_ARN   - Secrets Manager中存储数据库凭证的ARN (必需)
    AWS_REGION   - AWS区域 (必需)

依赖工具:
    - aws CLI (已配置凭证)
    - psql (PostgreSQL客户端)
    - jq (JSON处理工具)

示例:
    export CLUSTER_ARN="arn:aws-cn:rds:cn-northwest-1:123456789012:cluster:my-cluster"
    export SECRET_ARN="arn:aws-cn:secretsmanager:cn-northwest-1:123456789012:secret:rds-db-credentials/cluster-123456/postgres"
    export AWS_REGION="cn-northwest-1"
    $0

注意:
    - 此脚本适用于中国区，使用直接数据库连接
    - 需要网络能够访问 RDS 集群
    - 确保安全组允许 PostgreSQL 连接 (端口 5432)
    - 如果 RDS 在私有子网，需要通过堡垒机或 VPN 连接

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