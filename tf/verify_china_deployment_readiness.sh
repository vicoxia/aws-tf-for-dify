#!/bin/bash

echo "=== 中国区部署准备情况检查 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查区域配置
check_region_config() {
    echo ""
    echo "1. 检查区域配置..."
    
    if [ -f "terraform.tfvars" ]; then
        REGION=$(grep "aws_region" terraform.tfvars | cut -d'"' -f2 2>/dev/null)
        if [ -n "$REGION" ]; then
            print_success "找到区域配置: $REGION"
            
            if [[ "$REGION" == "cn-north-1" || "$REGION" == "cn-northwest-1" ]]; then
                print_success "确认为中国区域"
                IS_CHINA_REGION=true
            else
                print_warning "非中国区域，某些检查项不适用"
                IS_CHINA_REGION=false
            fi
        else
            print_error "未找到 aws_region 配置"
        fi
    else
        print_error "未找到 terraform.tfvars 文件"
    fi
}

# 检查必要工具
check_dependencies() {
    echo ""
    echo "2. 检查必要工具..."
    
    # 检查 Terraform
    if command -v terraform &> /dev/null; then
        TERRAFORM_VERSION=$(terraform version | head -1)
        print_success "Terraform: $TERRAFORM_VERSION"
    else
        print_error "Terraform 未安装"
    fi
    
    # 检查 AWS CLI
    if command -v aws &> /dev/null; then
        AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
        print_success "AWS CLI: $AWS_VERSION"
        
        # 检查 AWS 凭证
        if aws sts get-caller-identity &>/dev/null; then
            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
            print_success "AWS 凭证已配置 (Account: $ACCOUNT_ID)"
        else
            print_error "AWS 凭证未配置或无效"
        fi
    else
        print_error "AWS CLI 未安装"
    fi
    
    # 中国区特殊检查
    if [ "$IS_CHINA_REGION" = true ]; then
        echo ""
        echo "   中国区特殊依赖检查:"
        
        # 检查 PostgreSQL 客户端
        if command -v psql &> /dev/null; then
            PSQL_VERSION=$(psql --version | head -1)
            print_success "PostgreSQL 客户端: $PSQL_VERSION"
        else
            print_error "PostgreSQL 客户端 (psql) 未安装"
            echo "         安装命令: sudo apt-get install postgresql-client"
        fi
        
        # 检查 jq
        if command -v jq &> /dev/null; then
            JQ_VERSION=$(jq --version)
            print_success "jq: $JQ_VERSION"
        else
            print_error "jq 未安装"
            echo "         安装命令: sudo apt-get install jq"
        fi
    fi
}

# 检查脚本文件
check_scripts() {
    echo ""
    echo "3. 检查数据库创建脚本..."
    
    # 检查 Data API 脚本
    if [ -f "create_dify_databases_dataapi.sh" ]; then
        if [ -x "create_dify_databases_dataapi.sh" ]; then
            print_success "Data API 脚本: 存在且可执行"
        else
            print_warning "Data API 脚本: 存在但不可执行"
            echo "         修复命令: chmod +x create_dify_databases_dataapi.sh"
        fi
    else
        print_error "Data API 脚本: 不存在"
    fi
    
    # 检查中国区脚本
    if [ -f "create_dify_databases_china.sh" ]; then
        if [ -x "create_dify_databases_china.sh" ]; then
            print_success "中国区脚本: 存在且可执行"
        else
            print_warning "中国区脚本: 存在但不可执行"
            echo "         修复命令: chmod +x create_dify_databases_china.sh"
        fi
    else
        print_error "中国区脚本: 不存在"
    fi
}

# 检查网络连通性
check_network() {
    echo ""
    echo "4. 检查网络连通性..."
    
    # 检查 Helm 仓库
    echo "   检查 Helm 仓库访问:"
    
    if curl -s --connect-timeout 10 -I "https://aws.github.io/eks-charts" > /dev/null 2>&1; then
        print_success "AWS 官方仓库可访问"
    else
        print_warning "AWS 官方仓库不可访问"
        
        # 检查备用仓库
        if curl -s --connect-timeout 10 -I "https://g-hsod9681-helm.pkg.coding.net/dify-artifact/eks-charts" > /dev/null 2>&1; then
            print_success "Coding.net 备用仓库可访问"
        else
            print_warning "备用仓库也不可访问"
        fi
    fi
    
    # 检查其他重要服务
    services=(
        "https://kubernetes.github.io/ingress-nginx"
        "https://charts.jetstack.io"
    )
    
    for service in "${services[@]}"; do
        if curl -s --connect-timeout 5 -I "$service" > /dev/null 2>&1; then
            print_success "$(basename "$service") 可访问"
        else
            print_warning "$(basename "$service") 不可访问"
        fi
    done
}

# 检查 Terraform 配置
check_terraform_config() {
    echo ""
    echo "5. 检查 Terraform 配置..."
    
    # 检查初始化状态
    if [ -d ".terraform" ]; then
        print_success "Terraform 已初始化"
    else
        print_warning "Terraform 未初始化"
        echo "         运行命令: terraform init"
    fi
    
    # 检查配置语法
    if terraform validate &>/dev/null; then
        print_success "Terraform 配置语法正确"
    else
        print_error "Terraform 配置语法错误"
        echo "         运行命令: terraform validate"
    fi
}

# 生成部署建议
generate_recommendations() {
    echo ""
    echo "=== 部署建议 ==="
    
    if [ "$IS_CHINA_REGION" = true ]; then
        echo ""
        echo "中国区部署建议:"
        echo "1. 确保网络可以访问 RDS 集群（VPN/堡垒机/公网）"
        echo "2. 配置安全组允许 PostgreSQL 连接（端口 5432）"
        echo "3. 如果 Helm 仓库访问有问题，配置备用仓库："
        echo "   custom_helm_repositories = {"
        echo "     aws_load_balancer_controller = \"https://g-hsod9681-helm.pkg.coding.net/dify-artifact/eks-charts\""
        echo "   }"
        echo "4. 准备好依赖工具: psql, jq"
    else
        echo ""
        echo "全球区域部署建议:"
        echo "1. 确保网络可以访问 AWS 服务"
        echo "2. 检查 IAM 权限配置"
        echo "3. 验证 RDS Data API 可用性"
    fi
    
    echo ""
    echo "通用建议:"
    echo "1. 运行 terraform plan 检查配置"
    echo "2. 小规模测试部署"
    echo "3. 监控部署过程中的错误日志"
}

# 主函数
main() {
    check_region_config
    check_dependencies
    check_scripts
    check_network
    check_terraform_config
    generate_recommendations
    
    echo ""
    echo "=== 检查完成 ==="
}

# 运行检查
main