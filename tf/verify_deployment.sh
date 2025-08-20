#!/bin/bash

# Dify Enterprise AWS Infrastructure Verification Script
# This script verifies that all resources are correctly created after terraform apply

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check required tools
check_prerequisites() {
    log_info "Checking required tools..."
    
    local tools=("aws" "kubectl" "terraform" "helm")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install missing tools and rerun the script"
        exit 1
    fi
    
    log_success "All required tools are installed"
}

# Get Terraform outputs
get_terraform_outputs() {
    log_info "Getting Terraform outputs..."
    
    if [ ! -f "terraform.tfstate" ]; then
        log_error "terraform.tfstate file not found, please ensure you're running the script in the correct directory"
        exit 1
    fi
    
    # Get key output variables
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
        log_error "Unable to get EKS cluster name, please check Terraform state"
        exit 1
    fi
    
    log_success "Successfully retrieved Terraform outputs"
}

# Verify VPC and network resources
verify_vpc() {
    log_info "Verifying VPC and network resources..."
    
    if [ -z "$VPC_ID" ]; then
        log_warning "Skipping VPC verification (using existing VPC)"
        return
    fi
    
    # Check VPC
    if aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$AWS_REGION" &>/dev/null; then
        log_success "VPC ($VPC_ID) exists and is accessible"
    else
        log_error "VPC ($VPC_ID) does not exist or is not accessible"
        return 1
    fi
    
    # Check subnets
    local subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region "$AWS_REGION" --query 'Subnets[].SubnetId' --output text)
    local subnet_count=$(echo "$subnets" | wc -w)
    
    if [ "$subnet_count" -ge 6 ]; then
        log_success "Found $subnet_count subnets (public + private)"
    else
        log_warning "Subnet count may be insufficient: $subnet_count"
    fi
    
    # Check NAT Gateway
    local nat_gateways=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --region "$AWS_REGION" --query 'NatGateways[?State==`available`]' --output text)
    if [ -n "$nat_gateways" ]; then
        log_success "NAT Gateway is created and available"
    else
        log_warning "No available NAT Gateway found"
    fi
}

# Verify EKS cluster
verify_eks() {
    log_info "Verifying EKS cluster..."
    
    # Check cluster status
    local cluster_status=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$cluster_status" = "ACTIVE" ]; then
        log_success "EKS cluster ($CLUSTER_NAME) status: ACTIVE"
    else
        log_error "EKS cluster status abnormal: $cluster_status"
        return 1
    fi
    
    # Check node groups
    local nodegroups=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'nodegroups' --output text)
    if [ -n "$nodegroups" ]; then
        log_success "Found node groups: $nodegroups"
        
        # Check node group status
        for ng in $nodegroups; do
            local ng_status=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$AWS_REGION" --query 'nodegroup.status' --output text)
            if [ "$ng_status" = "ACTIVE" ]; then
                log_success "Node group ($ng) status: ACTIVE"
            else
                log_warning "Node group ($ng) status: $ng_status"
            fi
        done
    else
        log_error "No node groups found"
        return 1
    fi
    
    # Update kubeconfig
    log_info "Updating kubeconfig..."
    if aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" &>/dev/null; then
        log_success "kubeconfig updated"
    else
        log_error "Failed to update kubeconfig"
        return 1
    fi
    
    # Check node status
    log_info "Checking Kubernetes node status..."
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    local total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [ "$ready_nodes" -gt 0 ] && [ "$ready_nodes" -eq "$total_nodes" ]; then
        log_success "All nodes ($ready_nodes/$total_nodes) are in normal status"
    else
        log_warning "Node status: $ready_nodes/$total_nodes Ready"
    fi
}

# Verify RDS
verify_rds() {
    log_info "Verifying Aurora PostgreSQL..."
    
    if [ -z "$RDS_ENDPOINT" ]; then
        log_error "RDS endpoint not found"
        return 1
    fi
    
    # Get cluster identifier
    local cluster_id=$(echo "$RDS_ENDPOINT" | cut -d'.' -f1)
    
    # Check Aurora cluster status
    local cluster_status=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --region "$AWS_REGION" --query 'DBClusters[0].Status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$cluster_status" = "available" ]; then
        log_success "Aurora cluster status: available"
        log_success "Aurora endpoint: $RDS_ENDPOINT"
    else
        log_error "Aurora cluster status abnormal: $cluster_status"
        return 1
    fi
    
    # Check Serverless v2 configuration
    local serverless_config=$(aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --region "$AWS_REGION" --query 'DBClusters[0].ServerlessV2ScalingConfiguration' --output text 2>/dev/null)
    if [ "$serverless_config" != "None" ]; then
        log_success "Aurora Serverless v2 configuration enabled"
    else
        log_warning "Serverless v2 configuration not detected"
    fi
}

# Verify ElastiCache Redis
verify_redis() {
    log_info "Verifying ElastiCache Redis..."
    
    if [ -z "$REDIS_ENDPOINT" ]; then
        log_error "Redis endpoint not found"
        return 1
    fi
    
    # Get replication group ID
    local replication_group_id="${CLUSTER_NAME}-redis"
    
    # Check Redis status
    local redis_status=$(aws elasticache describe-replication-groups --replication-group-id "$replication_group_id" --region "$AWS_REGION" --query 'ReplicationGroups[0].Status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$redis_status" = "available" ]; then
        log_success "Redis cluster status: available"
        log_success "Redis endpoint: $REDIS_ENDPOINT"
    else
        log_error "Redis cluster status abnormal: $redis_status"
        return 1
    fi
    
    # Check cluster mode
    local cluster_enabled=$(aws elasticache describe-replication-groups --replication-group-id "$replication_group_id" --region "$AWS_REGION" --query 'ReplicationGroups[0].ClusterEnabled' --output text 2>/dev/null)
    if [ "$cluster_enabled" = "False" ]; then
        log_success "Redis Cluster Mode: Disabled (meets requirements)"
    else
        log_warning "Redis Cluster Mode status: $cluster_enabled"
    fi
}

# Verify OpenSearch
verify_opensearch() {
    log_info "Verifying OpenSearch..."
    
    if [ -z "$OPENSEARCH_ENDPOINT" ]; then
        log_error "OpenSearch endpoint not found"
        return 1
    fi
    
    # Get domain name
    local domain_name="${CLUSTER_NAME}-opensearch"
    
    # Check OpenSearch status
    local os_status=$(aws opensearch describe-domain --domain-name "$domain_name" --region "$AWS_REGION" --query 'DomainStatus.Processing' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$os_status" = "False" ]; then
        log_success "OpenSearch domain status: running normally"
        log_success "OpenSearch endpoint: $OPENSEARCH_ENDPOINT"
    else
        log_warning "OpenSearch domain may be processing"
    fi
}

# Verify S3 bucket
verify_s3() {
    log_info "Verifying S3 bucket..."
    
    if [ -z "$S3_BUCKET" ]; then
        log_error "S3 bucket name not found"
        return 1
    fi
    
    # Check if bucket exists
    if aws s3api head-bucket --bucket "$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
        log_success "S3 bucket ($S3_BUCKET) exists and is accessible"
    else
        log_error "S3 bucket ($S3_BUCKET) does not exist or is not accessible"
        return 1
    fi
    
    # Check versioning
    local versioning=$(aws s3api get-bucket-versioning --bucket "$S3_BUCKET" --region "$AWS_REGION" --query 'Status' --output text 2>/dev/null || echo "None")
    if [ "$versioning" = "Enabled" ]; then
        log_success "S3 versioning is enabled"
    else
        log_warning "S3 versioning status: $versioning"
    fi
}

# Verify ECR repository
verify_ecr() {
    log_info "Verifying ECR repository..."
    
    if [ -z "$ECR_REPO" ]; then
        log_error "ECR repository URL not found"
        return 1
    fi
    
    # Extract repository name
    local repo_name=$(echo "$ECR_REPO" | cut -d'/' -f2)
    
    # Check ECR repository
    if aws ecr describe-repositories --repository-names "$repo_name" --region "$AWS_REGION" &>/dev/null; then
        log_success "ECR repository ($repo_name) exists and is accessible"
        log_success "ECR repository URL: $ECR_REPO"
    else
        log_error "ECR repository ($repo_name) does not exist or is not accessible"
        return 1
    fi
}

# Verify Helm deployment
verify_helm() {
    log_info "Verifying Helm deployment..."
    
    # Check AWS Load Balancer Controller
    if helm list -n kube-system | grep -q "aws-load-balancer-controller"; then
        local alb_status=$(helm status aws-load-balancer-controller -n kube-system -o json | jq -r '.info.status' 2>/dev/null || echo "unknown")
        if [ "$alb_status" = "deployed" ]; then
            log_success "AWS Load Balancer Controller: deployed"
        else
            log_warning "AWS Load Balancer Controller status: $alb_status"
        fi
    else
        log_warning "AWS Load Balancer Controller not installed"
    fi
    
    # Check Cert-Manager
    if helm list -n cert-manager | grep -q "cert-manager"; then
        local cm_status=$(helm status cert-manager -n cert-manager -o json | jq -r '.info.status' 2>/dev/null || echo "unknown")
        if [ "$cm_status" = "deployed" ]; then
            log_success "Cert-Manager: deployed"
        else
            log_warning "Cert-Manager status: $cm_status"
        fi
    else
        log_warning "Cert-Manager not installed"
    fi
}

# Verify Kubernetes resources
verify_kubernetes() {
    log_info "Verifying Kubernetes resources..."
    
    # Check namespace
    local dify_ns=$(kubectl get namespace dify -o name 2>/dev/null || echo "")
    if [ -n "$dify_ns" ]; then
        log_success "Dify namespace created"
    else
        log_warning "Dify namespace not found"
    fi
    
    # Check ServiceAccounts
    local service_accounts=$(kubectl get serviceaccounts -n dify --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$service_accounts" -gt 0 ]; then
        log_success "Found $service_accounts ServiceAccounts"
    else
        log_warning "No ServiceAccounts found"
    fi
    
    # Check critical system pods
    log_info "Checking system pod status..."
    
    # CoreDNS
    local coredns_ready=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$coredns_ready" -gt 0 ]; then
        log_success "CoreDNS pods running normally ($coredns_ready pods)"
    else
        log_warning "CoreDNS pod status abnormal"
    fi
    
    # AWS Load Balancer Controller
    local alb_pods=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$alb_pods" -gt 0 ]; then
        log_success "AWS Load Balancer Controller pods running normally"
    else
        log_warning "AWS Load Balancer Controller pods not running"
    fi
}

# Generate verification report
generate_report() {
    log_info "Generating verification report..."
    
    local report_file="../secret/deployment_verification_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
# Dify Enterprise AWS Infrastructure Verification Report
Generated at: $(date)
Cluster name: $CLUSTER_NAME
AWS region: $AWS_REGION

## Resource Status
- EKS cluster: $CLUSTER_NAME
- VPC ID: $VPC_ID
- S3 bucket: $S3_BUCKET
- ECR repository: $ECR_REPO
- RDS endpoint: $RDS_ENDPOINT
- Redis endpoint: $REDIS_ENDPOINT
- OpenSearch endpoint: $OPENSEARCH_ENDPOINT

## Next Steps
1. Configure kubectl to access the cluster:
   aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

2. Verify cluster connection:
   kubectl get nodes

3. Deploy Dify application:

4. Configure domain and SSL certificates:

## Important Information
- Please securely store database passwords and API keys
- Recommend configuring monitoring and log collection
- Regularly backup important data
EOF
    
    log_success "Verification report generated: $report_file"
}

# Main function
main() {
    echo "=========================================="
    echo "  Dify Enterprise AWS Infrastructure Verification Script"
    echo "=========================================="
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Get Terraform outputs
    get_terraform_outputs
    
    echo
    log_info "Starting to verify deployed resources..."
    echo
    
    # Verify components
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
    log_info "Verification completed!"
    
    # Generate report
    generate_report
    
    echo
    log_success "All verification steps completed. Please review the output above for detailed status."
    echo
    echo "If any issues are found, please check:"
    echo "1. AWS credentials and permissions"
    echo "2. Terraform state file"
    echo "3. Network connectivity"
    echo "4. Resource quota limits"
    echo
}

# Run main function
main "$@"