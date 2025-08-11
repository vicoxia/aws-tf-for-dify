#!/bin/bash

# Dify企业版部署配置生成脚本
# 在terraform apply成功后运行，生成Dify部署所需的配置信息

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# 检查Terraform状态
check_terraform_state() {
    if [ ! -f "terraform.tfstate" ]; then
        log_error "未找到terraform.tfstate文件，请确保terraform apply已成功运行"
        exit 1
    fi
    
    # 检查Terraform状态是否有错误
    if ! terraform show &>/dev/null; then
        log_error "Terraform状态文件损坏或无效"
        exit 1
    fi
    
    log_success "Terraform状态文件验证通过"
}

# 获取所有Terraform输出
get_terraform_outputs() {
    log_info "获取Terraform输出信息..."
    
    # 基础信息
    ENVIRONMENT=$(terraform output -raw environment 2>/dev/null || echo "unknown")
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "unknown")
    AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id 2>/dev/null || echo "unknown")
    
    # EKS信息
    CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
    CLUSTER_ENDPOINT=$(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo "")
    CLUSTER_SECURITY_GROUP_ID=$(terraform output -raw eks_cluster_security_group_id 2>/dev/null || echo "")
    
    # 存储信息
    S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    S3_BUCKET_ARN=$(terraform output -raw s3_bucket_arn 2>/dev/null || echo "")
    S3_IAM_ROLE_ARN=$(terraform output -raw s3_iam_role_arn 2>/dev/null || echo "")
    
    # ECR信息
    ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
    ECR_EE_PLUGIN_REPOSITORY_URL=$(terraform output -raw ecr_ee_plugin_repository_url 2>/dev/null || echo "")
    ECR_EE_PLUGIN_REPOSITORY_NAME=$(terraform output -raw ecr_ee_plugin_repository_name 2>/dev/null || echo "")
    
    # 数据库信息（包括敏感信息）
    RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
    RDS_READER_ENDPOINT=$(terraform output -raw rds_reader_endpoint 2>/dev/null || echo "")
    RDS_PORT=$(terraform output -raw rds_port 2>/dev/null || echo "5432")
    RDS_DATABASE_NAME=$(terraform output -raw rds_database_name 2>/dev/null || echo "dify")
    RDS_USERNAME=$(terraform output -raw rds_username 2>/dev/null || echo "postgres")
    
    # Redis信息
    REDIS_ENDPOINT=$(terraform output -raw redis_endpoint 2>/dev/null || echo "")
    REDIS_PORT=$(terraform output -raw redis_port 2>/dev/null || echo "6379")
    
    # OpenSearch信息
    OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_endpoint 2>/dev/null || echo "")
    OPENSEARCH_DASHBOARD_ENDPOINT=$(terraform output -raw opensearch_dashboard_endpoint 2>/dev/null || echo "")
    
    # 网络信息
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    PRIVATE_SUBNET_IDS=$(terraform output -json private_subnet_ids 2>/dev/null | jq -r '.[]' | tr '\n' ',' | sed 's/,$//' || echo "")
    PUBLIC_SUBNET_IDS=$(terraform output -json public_subnet_ids 2>/dev/null | jq -r '.[]' | tr '\n' ',' | sed 's/,$//' || echo "")
    
    # IRSA角色信息
    DIFY_EE_S3_ROLE_ARN=$(terraform output -raw dify_ee_s3_role_arn 2>/dev/null || echo "")
    DIFY_EE_S3_ECR_ROLE_ARN=$(terraform output -raw dify_ee_s3_ecr_role_arn 2>/dev/null || echo "")
    DIFY_EE_ECR_PULL_ROLE_ARN=$(terraform output -raw dify_ee_ecr_pull_role_arn 2>/dev/null || echo "")
    
    # ServiceAccount信息
    SERVICE_ACCOUNTS_INFO=$(terraform output -json dify_ee_service_accounts_info 2>/dev/null || echo "{}")
    
    # Helm部署状态
    HELM_RELEASES_STATUS=$(terraform output -json helm_releases_status 2>/dev/null || echo "{}")
    
    log_success "成功获取所有Terraform输出"
}

# 从RDS配置文件中提取密码
get_database_passwords() {
    log_info "提取数据库密码信息..."
    
    # 从rds.tf文件中提取密码（这是硬编码的）
    if [ -f "rds.tf" ]; then
        RDS_PASSWORD=$(grep "master_password" rds.tf | sed 's/.*= *"\([^"]*\)".*/\1/' | head -1 || echo "")
        if [ -z "$RDS_PASSWORD" ]; then
            RDS_PASSWORD="DifyRdsPassword123!"  # 默认密码
            log_warning "使用默认RDS密码，请确认rds.tf中的实际密码"
        fi
    else
        RDS_PASSWORD="DifyRdsPassword123!"
        log_warning "未找到rds.tf文件，使用默认密码"
    fi
    
    # 从opensearch.tf文件中提取密码
    if [ -f "opensearch.tf" ]; then
        OPENSEARCH_PASSWORD=$(grep "master_password" opensearch.tf | sed 's/.*= *"\([^"]*\)".*/\1/' | head -1 || echo "")
        if [ -z "$OPENSEARCH_PASSWORD" ]; then
            OPENSEARCH_PASSWORD="DifyOpenSearch123!"  # 默认密码
            log_warning "使用默认OpenSearch密码，请确认opensearch.tf中的实际密码"
        fi
    else
        OPENSEARCH_PASSWORD="DifyOpenSearch123!"
        log_warning "未找到opensearch.tf文件，使用默认密码"
    fi
    
    log_success "数据库密码信息提取完成"
}

# 生成Dify部署配置文件
generate_dify_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local config_file="dify_deployment_config_${timestamp}.txt"
    local values_file="dify_values_${timestamp}.yaml"
    
    log_info "生成Dify部署配置文件..."
    
    # 生成详细配置文件
    cat > "$config_file" << EOF
# ========================================
# Dify企业版部署配置信息
# 生成时间: $(date)
# 环境: $ENVIRONMENT
# ========================================

## 基础信息
ENVIRONMENT=$ENVIRONMENT
AWS_REGION=$AWS_REGION
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID

## EKS集群信息
CLUSTER_NAME=$CLUSTER_NAME
CLUSTER_ENDPOINT=$CLUSTER_ENDPOINT
CLUSTER_SECURITY_GROUP_ID=$CLUSTER_SECURITY_GROUP_ID

## 网络信息
VPC_ID=$VPC_ID
PRIVATE_SUBNET_IDS=$PRIVATE_SUBNET_IDS
PUBLIC_SUBNET_IDS=$PUBLIC_SUBNET_IDS

## 存储信息
S3_BUCKET_NAME=$S3_BUCKET_NAME
S3_BUCKET_ARN=$S3_BUCKET_ARN
S3_IAM_ROLE_ARN=$S3_IAM_ROLE_ARN

## ECR容器仓库信息
ECR_REPOSITORY_URL=$ECR_REPOSITORY_URL
ECR_EE_PLUGIN_REPOSITORY_URL=$ECR_EE_PLUGIN_REPOSITORY_URL
ECR_EE_PLUGIN_REPOSITORY_NAME=$ECR_EE_PLUGIN_REPOSITORY_NAME

## 数据库信息（包含敏感信息）
RDS_ENDPOINT=$RDS_ENDPOINT
RDS_READER_ENDPOINT=$RDS_READER_ENDPOINT
RDS_PORT=$RDS_PORT
RDS_DATABASE_NAME=$RDS_DATABASE_NAME
RDS_USERNAME=$RDS_USERNAME
RDS_PASSWORD=$RDS_PASSWORD

## Redis缓存信息
REDIS_ENDPOINT=$REDIS_ENDPOINT
REDIS_PORT=$REDIS_PORT

## OpenSearch信息（包含敏感信息）
OPENSEARCH_ENDPOINT=$OPENSEARCH_ENDPOINT
OPENSEARCH_DASHBOARD_ENDPOINT=$OPENSEARCH_DASHBOARD_ENDPOINT
OPENSEARCH_USERNAME=admin
OPENSEARCH_PASSWORD=$OPENSEARCH_PASSWORD

## IRSA角色信息
DIFY_EE_S3_ROLE_ARN=$DIFY_EE_S3_ROLE_ARN
DIFY_EE_S3_ECR_ROLE_ARN=$DIFY_EE_S3_ECR_ROLE_ARN
DIFY_EE_ECR_PULL_ROLE_ARN=$DIFY_EE_ECR_PULL_ROLE_ARN

## ServiceAccount信息
# 详细信息请查看: terraform output dify_ee_service_accounts_info

## Helm部署状态
# 详细信息请查看: terraform output helm_releases_status

# ========================================
# 部署命令参考
# ========================================

## 1. 更新kubeconfig
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

## 2. 验证集群连接
kubectl get nodes

## 3. 添加Dify Helm仓库
helm repo add dify https://langgenius.github.io/dify-helm
helm repo update

## 4. 使用生成的values.yaml部署
helm upgrade -i dify -f $values_file dify/dify

# ========================================
# 重要提醒
# ========================================
# 1. 此文件包含敏感信息，请妥善保管
# 2. 不要将此文件提交到版本控制系统
# 3. 部署完成后建议删除此文件
# 4. 定期轮换数据库密码和API密钥
EOF

    # 生成Helm values.yaml文件
    cat > "$values_file" << EOF
###################################
# Dify企业版Helm Values配置
# 自动生成时间: $(date)
# 环境: $ENVIRONMENT
###################################

global:
  appSecretKey: 'dify123456'  # 请修改为安全的密钥
  consoleApiDomain: "console.dify.local"    # 请修改为实际域名
  consoleWebDomain: "console.dify.local"    # 请修改为实际域名
  serviceApiDomain: "api.dify.local"        # 请修改为实际域名
  appApiDomain: "app.dify.local"            # 请修改为实际域名
  appWebDomain: "app.dify.local"            # 请修改为实际域名
  filesDomain: "upload.dify.local"          # 请修改为实际域名
  enterpriseDomain: "enterprise.dify.local" # 请修改为实际域名

ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "15m"

# 根据环境调整副本数
EOF

    # 根据环境添加不同的资源配置
    if [ "$ENVIRONMENT" = "test" ]; then
        cat >> "$values_file" << EOF
# 测试环境配置
api:
  replicas: 1
  serverWorkerAmount: 1
  innerApi:
    apiKey: "dify123456"  # 请修改为安全的API密钥
  serviceAccountName: "dify-api-sa"

worker:
  replicas: 1
  celeryWorkerAmount: 1
  serviceAccountName: "dify-api-sa"

web:
  replicas: 1

sandbox:
  replicas: 1
  apiKey: "dify123456"  # 请修改为安全的API密钥

enterprise:
  replicas: 1
  appSecretKey: "dify123456"  # 请修改为安全的密钥
  adminAPIsSecretKeySalt: "dify123456"  # 请修改为安全的盐值
  innerApi:
    apiKey: "dify123456"  # 请修改为安全的API密钥

enterpriseAudit:
  replicas: 1

enterpriseFrontend:
  replicas: 1

ssrfProxy:
  enabled: true
  replicas: 1

unstructured:
  enabled: true
  replicas: 1

plugin_daemon:
  replicas: 1
  apiKey: "dify123456"  # 请修改为安全的API密钥

plugin_controller:
  replicas: 1

plugin_connector:
  replicas: 1
  apiKey: "dify123456"  # 请修改为安全的API密钥
  customServiceAccount: "dify-plugin-crd-sa"
  runnerServiceAccount: "dify-plugin-runner-sa"
  imageRepoPrefix: "$ECR_EE_PLUGIN_REPOSITORY_URL"
  imageRepoType: ecr
  ecrRegion: "$AWS_REGION"

gateway:
  replicas: 1
EOF
    else
        cat >> "$values_file" << EOF
# 生产环境配置
api:
  replicas: 3
  serverWorkerAmount: 1
  innerApi:
    apiKey: "dify123456"  # 请修改为安全的API密钥
  serviceAccountName: "dify-api-sa"
  resources:
    limits:
      cpu: 3000m
      memory: 10240Mi
    requests:
      cpu: 1500m
      memory: 5120Mi

worker:
  replicas: 3
  celeryWorkerAmount: 1
  serviceAccountName: "dify-api-sa"
  resources:
    limits:
      cpu: 2000m
      memory: 10240Mi
    requests:
      cpu: 1000m
      memory: 5120Mi

web:
  replicas: 3
  resources:
    limits:
      cpu: 1000m
      memory: 1024Mi
    requests:
      cpu: 500m
      memory: 512Mi

sandbox:
  replicas: 3
  apiKey: "dify123456"  # 请修改为安全的API密钥
  resources:
    limits:
      cpu: 1000m
      memory: 2048Mi
    requests:
      cpu: 500m
      memory: 1024Mi

enterprise:
  replicas: 3
  appSecretKey: "dify123456"  # 请修改为安全的密钥
  adminAPIsSecretKeySalt: "dify123456"  # 请修改为安全的盐值
  innerApi:
    apiKey: "dify123456"  # 请修改为安全的API密钥
  resources:
    limits:
      cpu: 1000m
      memory: 2048Mi
    requests:
      cpu: 500m
      memory: 1024Mi

enterpriseAudit:
  replicas: 3
  resources:
    limits:
      cpu: 1000m
      memory: 2048Mi
    requests:
      cpu: 500m
      memory: 1024Mi

enterpriseFrontend:
  replicas: 3
  resources:
    limits:
      cpu: 1000m
      memory: 1024Mi
    requests:
      cpu: 500m
      memory: 512Mi

ssrfProxy:
  enabled: true
  replicas: 3
  resources:
    limits:
      cpu: 1000m
      memory: 1024Mi
    requests:
      cpu: 500m
      memory: 512Mi

unstructured:
  enabled: true
  replicas: 3
  resources:
    limits:
      cpu: 1000m
      memory: 2048Mi
    requests:
      cpu: 500m
      memory: 1024Mi

plugin_daemon:
  replicas: 3
  apiKey: "dify123456"  # 请修改为安全的API密钥
  resources:
    limits:
      cpu: 1000m
      memory: 3072Mi
    requests:
      cpu: 500m
      memory: 1536Mi

plugin_controller:
  replicas: 3
  resources:
    limits:
      cpu: 1000m
      memory: 2048Mi
    requests:
      cpu: 500m
      memory: 1024Mi

plugin_connector:
  replicas: 3
  apiKey: "dify123456"  # 请修改为安全的API密钥
  customServiceAccount: "dify-plugin-crd-sa"
  runnerServiceAccount: "dify-plugin-runner-sa"
  imageRepoPrefix: "$ECR_EE_PLUGIN_REPOSITORY_URL"
  imageRepoType: ecr
  ecrRegion: "$AWS_REGION"
  resources:
    limits:
      cpu: 1000m
      memory: 2048Mi
    requests:
      cpu: 500m
      memory: 1024Mi

gateway:
  replicas: 3
  resources:
    limits:
      cpu: 1000m
      memory: 2048Mi
    requests:
      cpu: 500m
      memory: 1024Mi

minio:
  replicas: 1
  resources:
    limits:
      cpu: 1000m
      memory: 2048Mi
    requests:
      cpu: 500m
      memory: 1024Mi
EOF
    fi

    # 添加通用配置
    cat >> "$values_file" << EOF

###################################
# 持久化存储配置 (S3 + IRSA)
###################################
persistence:
  type: "s3"
  s3:
    endpoint: "https://s3.$AWS_REGION.amazonaws.com"
    region: "$AWS_REGION"
    bucketName: "$S3_BUCKET_NAME"
    useAwsS3: true
    useAwsManagedIam: true  # 使用IRSA模式

###################################
# 外部PostgreSQL配置
###################################
externalPostgres:
  enabled: true
  address: "$RDS_ENDPOINT"
  port: $RDS_PORT
  credentials:
    dify:
      database: "dify"
      username: "$RDS_USERNAME"
      password: "$RDS_PASSWORD"
      sslmode: "require"
    plugin_daemon:
      database: "dify_plugin_daemon"
      username: "$RDS_USERNAME"
      password: "$RDS_PASSWORD"
      sslmode: "require"
    enterprise:
      database: "enterprise"
      username: "$RDS_USERNAME"
      password: "$RDS_PASSWORD"
      sslmode: "require"
    audit:
      database: "audit"
      username: "$RDS_USERNAME"
      password: "$RDS_PASSWORD"
      sslmode: "require"

###################################
# 外部Redis配置
###################################
externalRedis:
  enabled: true
  host: "$REDIS_ENDPOINT"
  port: $REDIS_PORT
  username: ""
  password: ""  # Redis未设置密码
  useSSL: false

###################################
# 外部向量数据库配置 (OpenSearch)
###################################
vectorDB:
  useExternal: true
  externalType: "opensearch"
  externalOpensearch:
    endpoint: "https://$OPENSEARCH_ENDPOINT"
    username: "admin"
    password: "$OPENSEARCH_PASSWORD"
    # 如果使用自签名证书，设置为true
    verifyCerts: false

###################################
# 镜像拉取密钥（如果需要）
###################################
imagePullSecrets: []

###################################
# 重要提醒
###################################
# 1. 请修改所有默认密钥和API密钥为安全值
# 2. 请修改域名为实际使用的域名
# 3. 根据实际需求调整资源限制
# 4. 确保DNS记录指向Load Balancer
# 5. 配置SSL证书（如果使用Cert-Manager）
EOF

    log_success "配置文件生成完成:"
    log_success "  - 详细配置: $config_file"
    log_success "  - Helm Values: $values_file"
    
    # 设置文件权限（仅所有者可读写）
    chmod 600 "$config_file" "$values_file"
    log_warning "配置文件权限已设置为600（仅所有者可读写）"
}

# 生成部署脚本
generate_deployment_script() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local deploy_script="deploy_dify_${timestamp}.sh"
    local values_file="dify_values_${timestamp}.yaml"
    
    log_info "生成部署脚本..."
    
    cat > "$deploy_script" << EOF
#!/bin/bash

# Dify企业版自动部署脚本
# 生成时间: $(date)
# 环境: $ENVIRONMENT

set -e

echo "=========================================="
echo "  Dify企业版部署脚本"
echo "  环境: $ENVIRONMENT"
echo "  集群: $CLUSTER_NAME"
echo "=========================================="

# 1. 更新kubeconfig
echo "1. 更新kubeconfig..."
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# 2. 验证集群连接
echo "2. 验证集群连接..."
kubectl get nodes

# 3. 添加Dify Helm仓库
echo "3. 添加Dify Helm仓库..."
helm repo add dify https://langgenius.github.io/dify-helm
helm repo update

# 4. 创建命名空间（如果不存在）
echo "4. 创建Dify命名空间..."
kubectl create namespace dify --dry-run=client -o yaml | kubectl apply -f -

# 5. 部署Dify应用
echo "5. 部署Dify应用..."
helm upgrade -i dify -f $values_file dify/dify -n dify

# 6. 等待部署完成
echo "6. 等待部署完成..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=dify -n dify --timeout=600s

# 7. 显示部署状态
echo "7. 显示部署状态..."
kubectl get pods -n dify
kubectl get svc -n dify
kubectl get ingress -n dify

echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo
echo "下一步操作:"
echo "1. 配置DNS记录指向Load Balancer"
echo "2. 访问应用: https://console.dify.local"
echo "3. 查看日志: kubectl logs -f deployment/dify-api -n dify"
echo
EOF

    chmod +x "$deploy_script"
    log_success "部署脚本生成完成: $deploy_script"
}

# 生成输出日志
generate_output_log() {
    local output_file="out.log"
    
    log_info "生成Terraform输出日志..."
    
    # 生成完整的Terraform输出
    cat > "$output_file" << EOF
# ========================================
# Terraform输出日志
# 生成时间: $(date)
# ========================================

EOF
    
    # 添加所有Terraform输出（包括敏感信息）
    terraform output >> "$output_file" 2>&1
    
    # 添加敏感信息
    cat >> "$output_file" << EOF

# ========================================
# 敏感信息（手动添加）
# ========================================

# RDS数据库密码
RDS_PASSWORD = "$RDS_PASSWORD"

# OpenSearch管理员密码
OPENSEARCH_PASSWORD = "$OPENSEARCH_PASSWORD"

# ========================================
# 部署配置摘要
# ========================================

环境: $ENVIRONMENT
AWS区域: $AWS_REGION
EKS集群: $CLUSTER_NAME
S3存储桶: $S3_BUCKET_NAME
RDS端点: $RDS_ENDPOINT
Redis端点: $REDIS_ENDPOINT
OpenSearch端点: $OPENSEARCH_ENDPOINT

# ========================================
# 重要提醒
# ========================================
# 1. 此文件包含敏感信息，请妥善保管
# 2. 不要将此文件提交到版本控制系统
# 3. 使用完毕后请安全删除
EOF

    chmod 600 "$output_file"
    log_success "输出日志生成完成: $output_file"
}

# 主函数
main() {
    echo "=========================================="
    echo "  Dify企业版部署配置生成器"
    echo "=========================================="
    echo
    
    # 检查Terraform状态
    check_terraform_state
    
    # 获取Terraform输出
    get_terraform_outputs
    
    # 获取数据库密码
    get_database_passwords
    
    echo
    log_info "开始生成部署配置文件..."
    echo
    
    # 生成各种配置文件
    generate_dify_config
    generate_deployment_script
    generate_output_log
    
    echo
    log_success "所有配置文件生成完成！"
    echo
    echo "生成的文件:"
    echo "  - dify_deployment_config_*.txt  (详细配置信息)"
    echo "  - dify_values_*.yaml           (Helm Values配置)"
    echo "  - deploy_dify_*.sh             (自动部署脚本)"
    echo "  - out.log                      (Terraform输出日志)"
    echo
    log_warning "重要提醒:"
    echo "  1. 这些文件包含敏感信息，请妥善保管"
    echo "  2. 不要将这些文件提交到版本控制系统"
    echo "  3. 部署前请修改默认密钥和域名"
    echo "  4. 使用完毕后请安全删除敏感文件"
    echo
    echo "下一步操作:"
    echo "  1. 检查并修改生成的values.yaml文件"
    echo "  2. 运行部署脚本: ./deploy_dify_*.sh"
    echo "  3. 或手动部署: helm upgrade -i dify -f dify_values_*.yaml dify/dify"
    echo
}

# 运行主函数
main "$@"