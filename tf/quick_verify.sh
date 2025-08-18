#!/bin/bash

# Dify企业版AWS基础设施快速验证脚本
# 快速检查关键资源状态

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 获取Terraform输出
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || aws configure get region)

if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${RED}错误: 无法获取集群名称，请确保terraform已成功运行${NC}"
    exit 1
fi

echo "=========================================="
echo "  Dify基础设施快速验证"
echo "  集群: $CLUSTER_NAME"
echo "  区域: $AWS_REGION"
echo "=========================================="

# 验证EKS集群
echo -n "EKS集群状态: "
CLUSTER_STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.status' --output text 2>/dev/null || echo "ERROR")
if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
    echo -e "${GREEN}ACTIVE${NC}"
else
    echo -e "${RED}$CLUSTER_STATUS${NC}"
fi

# 验证节点组
echo -n "节点组状态: "
NODEGROUP=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'nodegroups[0]' --output text 2>/dev/null || echo "")
if [ -n "$NODEGROUP" ]; then
    NG_STATUS=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODEGROUP" --region "$AWS_REGION" --query 'nodegroup.status' --output text 2>/dev/null)
    if [ "$NG_STATUS" = "ACTIVE" ]; then
        echo -e "${GREEN}ACTIVE${NC}"
    else
        echo -e "${YELLOW}$NG_STATUS${NC}"
    fi
else
    echo -e "${RED}NOT_FOUND${NC}"
fi

# 验证RDS
echo -n "Aurora数据库: "
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
if [ -n "$RDS_ENDPOINT" ]; then
    CLUSTER_ID=$(echo "$RDS_ENDPOINT" | cut -d'.' -f1)
    RDS_STATUS=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" --region "$AWS_REGION" --query 'DBClusters[0].Status' --output text 2>/dev/null || echo "ERROR")
    if [ "$RDS_STATUS" = "available" ]; then
        echo -e "${GREEN}AVAILABLE${NC}"
    else
        echo -e "${YELLOW}$RDS_STATUS${NC}"
    fi
else
    echo -e "${RED}NOT_FOUND${NC}"
fi

# 验证Redis
echo -n "Redis缓存: "
REDIS_ID="${CLUSTER_NAME}-redis"
REDIS_STATUS=$(aws elasticache describe-replication-groups --replication-group-id "$REDIS_ID" --region "$AWS_REGION" --query 'ReplicationGroups[0].Status' --output text 2>/dev/null || echo "ERROR")
if [ "$REDIS_STATUS" = "available" ]; then
    echo -e "${GREEN}AVAILABLE${NC}"
else
    echo -e "${YELLOW}$REDIS_STATUS${NC}"
fi

# 验证OpenSearch
echo -n "OpenSearch: "
OS_DOMAIN="${CLUSTER_NAME}-opensearch"
OS_STATUS=$(aws opensearch describe-domain --domain-name "$OS_DOMAIN" --region "$AWS_REGION" --query 'DomainStatus.Processing' --output text 2>/dev/null || echo "ERROR")
if [ "$OS_STATUS" = "False" ]; then
    echo -e "${GREEN}AVAILABLE${NC}"
else
    echo -e "${YELLOW}PROCESSING${NC}"
fi

# 验证S3
echo -n "S3存储桶: "
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
if [ -n "$S3_BUCKET" ] && aws s3api head-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
    echo -e "${GREEN}ACCESSIBLE${NC}"
else
    echo -e "${RED}ERROR${NC}"
fi

# 验证ECR
echo -n "ECR仓库: "
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
if [ -n "$ECR_REPO" ]; then
    REPO_NAME=$(echo "$ECR_REPO" | cut -d'/' -f2)
    if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" &>/dev/null; then
        echo -e "${GREEN}ACCESSIBLE${NC}"
    else
        echo -e "${RED}ERROR${NC}"
    fi
else
    echo -e "${RED}NOT_FOUND${NC}"
fi

echo "=========================================="
echo "快速验证完成！"
echo
echo "下一步操作:"
echo "1. 更新 kubeconfig: aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME"
echo "2. 检查节点: kubectl get nodes"
echo "3. 运行 bash post_apply.sh 生成 helm values 所需的配置"
echo "4. [可选] 运行 terraform output dify_ee_service_accounts_info 查看 service account 信息"
echo "=========================================="