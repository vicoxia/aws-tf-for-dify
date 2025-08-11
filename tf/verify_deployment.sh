#!/bin/bash

# Dify企业版AWS基础设施验证脚本
# 此脚本验证terraform apply后所有资源是否正确创建

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的工具
check_prerequisites() {
    log_info "检查必要工具..."
    
    local tools=("aws" "kubectl" "terraform" "helm")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        log_error "请安装缺少的工具后重新运行脚本"
        exit 1
    fi
    
    log_success "所有必要工具已安装"
}

# 获取Terraform输出
get_terraform_outputs() {
    log_info "获取Terraform输出..."
    
    if [ ! -f "terraform.tfstate" ]; then
        log_error "未找到terraform.tfstate文件，请确保在正确的目录运行脚本"
        exit 1
    fi
    
    # 获取关键输出变量
    CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
    CLUSTER_ENDPOINT=$(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo "")
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
    RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
    REDIS_ENDPOINT=$(terraform output -raw redis_endpoint 2>/dev/null || echo "")
    OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_endpoint 2>/dev/null || echo "")
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || aws configure get region)
    
    if [ -z "$CLUSTER_NAME" ]; then
        log_error "无法获取EKS集群名称，请检查Terraform状态"
        exit 1
    fi
    
    log_success "成功获取Terraform输出"
}

# 验证VPC和网络资源
verify_vpc() {
    log_info "验证VPC和网络资源..."
    
    if [ -z "$VPC_ID" ]; then
        log_warning "跳过VPC验证（使用现有VPC）"
        return
    fi
    
    # 检查VPC
    if aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$AWS_REGION" &>/dev/null; then
        log_success "VPC ($VPC_ID) 存在且可访问"
    else
        log_error "VPC ($VPC_ID) 不存在或无法访问"
        return 1
    fi
    
    # 检查子网
    local subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region "$AWS_REGION" --query 'Subnets[].SubnetId' --output text)
    local subnet_count=$(echo "$subnets" | wc -w)
    
    if [ "$subnet_count" -ge 6 ]; then
        log_success "发现 $subnet_count 个子网（公有+私有）"
    else
        log_warning "子网数量可能不足: $subnet_count"
    fi
    
    # 检查NAT Gateway
    local nat_gateways=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --region "$AWS_REGION" --query 'NatGateways[?State==`available`]' --output text)
    if [ -n "$nat_gateways" ]; then
        log_success "NAT Gateway 已创建并可用"
    else
        log_warning "未找到可用的NAT Gateway"
    fi
}

# 验证EKS集群
verify_eks() {
    log_info "验证EKS集群..."
    
    # 检查集群状态
    local cluster_status=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$cluster_status" = "ACTIVE" ]; then
        log_success "EKS集群 ($CLUSTER_NAME) 状态: ACTIVE"
    else
        log_error "EKS集群状态异常: $cluster_status"
        return 1
    fi
    
    # 检查节点组
    local nodegroups=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'nodegroups' --output text)
    if [ -n "$nodegroups" ]; then
        log_success "发现节点组: $nodegroups"
        
        # 检查节点组状态
        for ng in $nodegroups; do
            local ng_status=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$AWS_REGION" --query 'nodegroup.status' --output text)
            if [ "$ng_status" = "ACTIVE" ]; then
                log_success "节点组 ($ng) 状态: ACTIVE"
            else
                log_warning "节点组 ($ng) 状态: $ng_status"
            fi
        done
    else
        log_error "未找到节点组"
        return 1
    fi
    
    # 更新kubeconfig
    log_info "更新kubeconfig..."
    if aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" &>/dev/null; then
        log_success "kubeconfig已更新"
    else
        log_error "更新kubeconfig失败"
        return 1
    fi
    
    # 检查节点状态
    log_info "检查Kubernetes节点状态..."
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    local total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [ "$ready_nodes" -gt 0 ] && [ "$ready_nodes" -eq "$total_nodes" ]; then
        log_success "所有节点 ($ready_nodes/$total_nodes) 状态正常"
    else
        log_warning "节点状态: $ready_nodes/$total_nodes Ready"
    fi
}

# 验证RDS
verify_rds() {
    log_info "验证Aurora PostgreSQL..."
    
    if [ -z "$RDS_ENDPOINT" ]; then
        log_error "未找到RDS端点"
        return 1
    fi
    
    # 获取集群标识符
    local cluster_id=$(echo "$RDS_ENDPOINT" | cut -d'.' -f1)
    
    # 检查Aurora集群状态
    local cluster_status=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --region "$AWS_REGION" --query 'DBClusters[0].Status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$cluster_status" = "available" ]; then
        log_success "Aurora集群状态: available"
        log_success "Aurora端点: $RDS_ENDPOINT"
    else
        log_error "Aurora集群状态异常: $cluster_status"
        return 1
    fi
    
    # 检查Serverless v2配置
    local serverless_config=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --region "$AWS_REGION" --query 'DBClusters[0].ServerlessV2ScalingConfiguration' --output text 2>/dev/null)
    if [ "$serverless_config" != "None" ]; then
        log_success "Aurora Serverless v2配置已启用"
    else
        log_warning "未检测到Serverless v2配置"
    fi
}

# 验证ElastiCache Redis
verify_redis() {
    log_info "验证ElastiCache Redis..."
    
    if [ -z "$REDIS_ENDPOINT" ]; then
        log_error "未找到Redis端点"
        return 1
    fi
    
    # 获取复制组ID
    local replication_group_id="${CLUSTER_NAME}-redis"
    
    # 检查Redis状态
    local redis_status=$(aws elasticache describe-replication-groups --replication-group-id "$replication_group_id" --region "$AWS_REGION" --query 'ReplicationGroups[0].Status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$redis_status" = "available" ]; then
        log_success "Redis集群状态: available"
        log_success "Redis端点: $REDIS_ENDPOINT"
    else
        log_error "Redis集群状态异常: $redis_status"
        return 1
    fi
    
    # 检查集群模式
    local cluster_enabled=$(aws elasticache describe-replication-groups --replication-group-id "$replication_group_id" --region "$AWS_REGION" --query 'ReplicationGroups[0].ClusterEnabled' --output text 2>/dev/null)
    if [ "$cluster_enabled" = "False" ]; then
        log_success "Redis Cluster Mode: Disabled (符合要求)"
    else
        log_warning "Redis Cluster Mode状态: $cluster_enabled"
    fi
}

# 验证OpenSearch
verify_opensearch() {
    log_info "验证OpenSearch..."
    
    if [ -z "$OPENSEARCH_ENDPOINT" ]; then
        log_error "未找到OpenSearch端点"
        return 1
    fi
    
    # 获取域名
    local domain_name="${CLUSTER_NAME}-opensearch"
    
    # 检查OpenSearch状态
    local os_status=$(aws opensearch describe-domain --domain-name "$domain_name" --region "$AWS_REGION" --query 'DomainStatus.Processing' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$os_status" = "False" ]; then
        log_success "OpenSearch域状态: 正常运行"
        log_success "OpenSearch端点: $OPENSEARCH_ENDPOINT"
    else
        log_warning "OpenSearch域可能正在处理中"
    fi
}

# 验证S3存储桶
verify_s3() {
    log_info "验证S3存储桶..."
    
    if [ -z "$S3_BUCKET" ]; then
        log_error "未找到S3存储桶名称"
        return 1
    fi
    
    # 检查存储桶是否存在
    if aws s3api head-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
        log_success "S3存储桶 ($S3_BUCKET) 存在且可访问"
    else
        log_error "S3存储桶 ($S3_BUCKET) 不存在或无法访问"
        return 1
    fi
    
    # 检查版本控制
    local versioning=$(aws s3api get-bucket-versioning --bucket "$S3_BUCKET" --region "$AWS_REGION" --query 'Status' --output text 2>/dev/null || echo "None")
    if [ "$versioning" = "Enabled" ]; then
        log_success "S3版本控制已启用"
    else
        log_warning "S3版本控制状态: $versioning"
    fi
}

# 验证ECR仓库
verify_ecr() {
    log_info "验证ECR仓库..."
    
    if [ -z "$ECR_REPO" ]; then
        log_error "未找到ECR仓库URL"
        return 1
    fi
    
    # 提取仓库名称
    local repo_name=$(echo "$ECR_REPO" | cut -d'/' -f2)
    
    # 检查ECR仓库
    if aws ecr describe-repositories --repository-names "$repo_name" --region "$AWS_REGION" &>/dev/null; then
        log_success "ECR仓库 ($repo_name) 存在且可访问"
        log_success "ECR仓库URL: $ECR_REPO"
    else
        log_error "ECR仓库 ($repo_name) 不存在或无法访问"
        return 1
    fi
}

# 验证Helm部署
verify_helm() {
    log_info "验证Helm部署..."
    
    # 检查AWS Load Balancer Controller
    if helm list -n kube-system | grep -q "aws-load-balancer-controller"; then
        local alb_status=$(helm status aws-load-balancer-controller -n kube-system -o json | jq -r '.info.status' 2>/dev/null || echo "unknown")
        if [ "$alb_status" = "deployed" ]; then
            log_success "AWS Load Balancer Controller: deployed"
        else
            log_warning "AWS Load Balancer Controller状态: $alb_status"
        fi
    else
        log_warning "AWS Load Balancer Controller未安装"
    fi
    
    # 检查Cert-Manager
    if helm list -n cert-manager | grep -q "cert-manager"; then
        local cm_status=$(helm status cert-manager -n cert-manager -o json | jq -r '.info.status' 2>/dev/null || echo "unknown")
        if [ "$cm_status" = "deployed" ]; then
            log_success "Cert-Manager: deployed"
        else
            log_warning "Cert-Manager状态: $cm_status"
        fi
    else
        log_warning "Cert-Manager未安装"
    fi
}

# 验证Kubernetes资源
verify_kubernetes() {
    log_info "验证Kubernetes资源..."
    
    # 检查命名空间
    local dify_ns=$(kubectl get namespace dify -o name 2>/dev/null || echo "")
    if [ -n "$dify_ns" ]; then
        log_success "Dify命名空间已创建"
    else
        log_warning "Dify命名空间未找到"
    fi
    
    # 检查ServiceAccounts
    local service_accounts=$(kubectl get serviceaccounts -n dify --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$service_accounts" -gt 0 ]; then
        log_success "发现 $service_accounts 个ServiceAccount"
    else
        log_warning "未找到ServiceAccount"
    fi
    
    # 检查关键系统Pod
    log_info "检查系统Pod状态..."
    
    # CoreDNS
    local coredns_ready=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$coredns_ready" -gt 0 ]; then
        log_success "CoreDNS Pod运行正常 ($coredns_ready个)"
    else
        log_warning "CoreDNS Pod状态异常"
    fi
    
    # AWS Load Balancer Controller
    local alb_pods=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$alb_pods" -gt 0 ]; then
        log_success "AWS Load Balancer Controller Pod运行正常"
    else
        log_warning "AWS Load Balancer Controller Pod未运行"
    fi
}

# 生成验证报告
generate_report() {
    log_info "生成验证报告..."
    
    local report_file="deployment_verification_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
# Dify企业版AWS基础设施验证报告
生成时间: $(date)
集群名称: $CLUSTER_NAME
AWS区域: $AWS_REGION

## 资源状态
- EKS集群: $CLUSTER_NAME
- VPC ID: $VPC_ID
- S3存储桶: $S3_BUCKET
- ECR仓库: $ECR_REPO
- RDS端点: $RDS_ENDPOINT
- Redis端点: $REDIS_ENDPOINT
- OpenSearch端点: $OPENSEARCH_ENDPOINT

## 下一步操作
1. 配置kubectl访问集群:
   aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

2. 验证集群连接:
   kubectl get nodes

3. 部署Dify应用:
   参考 additional_docs/ 目录下的部署文档

4. 配置域名和SSL证书:
   参考官方文档配置Ingress和证书

## 重要信息
- 请妥善保存数据库密码和API密钥
- 建议配置监控和日志收集
- 定期备份重要数据
EOF
    
    log_success "验证报告已生成: $report_file"
}

# 主函数
main() {
    echo "=========================================="
    echo "  Dify企业版AWS基础设施验证脚本"
    echo "=========================================="
    echo
    
    # 检查先决条件
    check_prerequisites
    
    # 获取Terraform输出
    get_terraform_outputs
    
    echo
    log_info "开始验证部署的资源..."
    echo
    
    # 验证各个组件
    verify_vpc
    verify_eks
    verify_rds
    verify_redis
    verify_opensearch
    verify_s3
    verify_ecr
    verify_helm
    verify_kubernetes
    
    echo
    log_info "验证完成！"
    
    # 生成报告
    generate_report
    
    echo
    log_success "所有验证步骤已完成。请查看上述输出了解详细状态。"
    echo
    echo "如果发现任何问题，请检查:"
    echo "1. AWS凭证和权限"
    echo "2. Terraform状态文件"
    echo "3. 网络连接"
    echo "4. 资源配额限制"
    echo
}

# 运行主函数
main "$@"