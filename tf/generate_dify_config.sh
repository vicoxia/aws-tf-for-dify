#!/bin/bash

# Dify Enterprise Edition Deployment Configuration Generator Script
# Run after successful terraform apply to generate configuration information required for Dify deployment

set -e

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Log functions
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

# Check Terraform state
check_terraform_state() {
    if [ ! -f "terraform.tfstate" ]; then
        log_error "terraform.tfstate file not found, please ensure terraform apply has run successfully"
        exit 1
    fi
    
    # Check if Terraform state has any errors
    if ! terraform show &>/dev/null; then
        log_error "Terraform state file is corrupted or invalid"
        exit 1
    fi
    
    log_success "Terraform state file validation passed"
}

# Get all Terraform outputs
get_terraform_outputs() {
    log_info "Getting Terraform output information..."
    
    # Basic information
    ENVIRONMENT=$(terraform output -raw environment 2>/dev/null || echo "unknown")
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "unknown")
    AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id 2>/dev/null || echo "unknown")
    
    # EKS information
    CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
    CLUSTER_ENDPOINT=$(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo "")
    CLUSTER_SECURITY_GROUP_ID=$(terraform output -raw eks_cluster_security_group_id 2>/dev/null || echo "")
    
    # Storage information
    S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    S3_BUCKET_ARN=$(terraform output -raw s3_bucket_arn 2>/dev/null || echo "")
    S3_IAM_ROLE_ARN=$(terraform output -raw s3_iam_role_arn 2>/dev/null || echo "")
    
    # ECR information
    ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
    ECR_EE_PLUGIN_REPOSITORY_URL=$(terraform output -raw ecr_ee_plugin_repository_url 2>/dev/null || echo "")
    ECR_EE_PLUGIN_REPOSITORY_NAME=$(terraform output -raw ecr_ee_plugin_repository_name 2>/dev/null || echo "")
    
    # Database information (including sensitive info)
    RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
    RDS_READER_ENDPOINT=$(terraform output -raw rds_reader_endpoint 2>/dev/null || echo "")
    RDS_PORT=$(terraform output -raw rds_port 2>/dev/null || echo "5432")
    RDS_DATABASE_NAME=$(terraform output -raw rds_database_name 2>/dev/null || echo "dify")
    RDS_USERNAME=$(terraform output -raw rds_username 2>/dev/null || echo "postgres")
    
    # Redis information
    REDIS_ENDPOINT=$(terraform output -raw redis_endpoint 2>/dev/null || echo "")
    REDIS_PORT=$(terraform output -raw redis_port 2>/dev/null || echo "6379")
    
    # OpenSearch information
    OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_endpoint 2>/dev/null || echo "")
    OPENSEARCH_DASHBOARD_ENDPOINT=$(terraform output -raw opensearch_dashboard_endpoint 2>/dev/null || echo "")
    
    # Network information
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    PRIVATE_SUBNET_IDS=$(terraform output -json private_subnet_ids 2>/dev/null | jq -r '.[]' | tr '\n' ',' | sed 's/,$//' || echo "")
    PUBLIC_SUBNET_IDS=$(terraform output -json public_subnet_ids 2>/dev/null | jq -r '.[]' | tr '\n' ',' | sed 's/,$//' || echo "")
    
    # IRSA role information
    DIFY_EE_S3_ROLE_ARN=$(terraform output -raw dify_ee_s3_role_arn 2>/dev/null || echo "")
    DIFY_EE_S3_ECR_ROLE_ARN=$(terraform output -raw dify_ee_s3_ecr_role_arn 2>/dev/null || echo "")
    DIFY_EE_ECR_PULL_ROLE_ARN=$(terraform output -raw dify_ee_ecr_pull_role_arn 2>/dev/null || echo "")
    
    # ServiceAccount information
    SERVICE_ACCOUNTS_INFO=$(terraform output -json dify_ee_service_accounts_info 2>/dev/null || echo "{}")
    
    # Helm deployment status
    HELM_RELEASES_STATUS=$(terraform output -json helm_releases_status 2>/dev/null || echo "{}")
    
    log_success "Successfully retrieved all Terraform outputs"
}

# Extract passwords from RDS configuration files
get_database_passwords() {
    log_info "Extracting database password information..."
    
    # Extract password from rds.tf file (hardcoded)
    if [ -f "rds.tf" ]; then
        RDS_PASSWORD=$(grep "master_password" rds.tf | sed 's/.*= *"\([^"]*\)".*/\1/' | head -1 || echo "")
        if [ -z "$RDS_PASSWORD" ]; then
            RDS_PASSWORD="DifyRdsPassword123!"  # Default password
            log_warning "Using default RDS password, please confirm actual password in rds.tf"
        fi
    else
        RDS_PASSWORD="DifyRdsPassword123!"
        log_warning "rds.tf file not found, using default password"
    fi
    
    # Extract password from opensearch.tf file
    if [ -f "opensearch.tf" ]; then
        OPENSEARCH_PASSWORD=$(grep "master_password" opensearch.tf | sed 's/.*= *"\([^"]*\)".*/\1/' | head -1 || echo "")
        if [ -z "$OPENSEARCH_PASSWORD" ]; then
            OPENSEARCH_PASSWORD="DifyOpenSearch123!"  # Default password
            log_warning "Using default OpenSearch password, please confirm actual password in opensearch.tf"
        fi
    else
        OPENSEARCH_PASSWORD="DifyOpenSearch123!"
        log_warning "opensearch.tf file not found, using default password"
    fi
    
    log_success "Database password information extraction completed"
}

# Generate Dify deployment configuration file
generate_dify_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Create secret directory (in parent directory of tf)
    mkdir -p ../secret
    
    local config_file="../secret/dify_deployment_config_${timestamp}.txt"
    # local values_file="../secret/dify_values_${timestamp}.yaml"  # Commented out - not generating values file
    
    log_info "Generating Dify deployment configuration file..."
    
    # Generate detailed configuration file
    cat > "$config_file" << EOF
# ========================================
# Dify Enterprise Edition Deployment Configuration
# Generated at: $(date)
# Environment: $ENVIRONMENT
# ========================================

## Basic Information
ENVIRONMENT=$ENVIRONMENT
AWS_REGION=$AWS_REGION
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID

## EKS Cluster Information
CLUSTER_NAME=$CLUSTER_NAME
CLUSTER_ENDPOINT=$CLUSTER_ENDPOINT
CLUSTER_SECURITY_GROUP_ID=$CLUSTER_SECURITY_GROUP_ID

## Network Information
VPC_ID=$VPC_ID
PRIVATE_SUBNET_IDS=$PRIVATE_SUBNET_IDS
PUBLIC_SUBNET_IDS=$PUBLIC_SUBNET_IDS

## Storage Information
S3_BUCKET_NAME=$S3_BUCKET_NAME
S3_BUCKET_ARN=$S3_BUCKET_ARN
S3_IAM_ROLE_ARN=$S3_IAM_ROLE_ARN

## ECR Container Registry Information
ECR_REPOSITORY_URL=$ECR_REPOSITORY_URL
ECR_EE_PLUGIN_REPOSITORY_URL=$ECR_EE_PLUGIN_REPOSITORY_URL
ECR_EE_PLUGIN_REPOSITORY_NAME=$ECR_EE_PLUGIN_REPOSITORY_NAME

## Database Information (including sensitive info)
RDS_ENDPOINT=$RDS_ENDPOINT
RDS_READER_ENDPOINT=$RDS_READER_ENDPOINT
RDS_PORT=$RDS_PORT
RDS_DATABASE_NAME=$RDS_DATABASE_NAME
RDS_USERNAME=$RDS_USERNAME
RDS_PASSWORD=$RDS_PASSWORD

## Redis Cache Information
REDIS_ENDPOINT=$REDIS_ENDPOINT
REDIS_PORT=$REDIS_PORT

## OpenSearch Information (including sensitive info)
OPENSEARCH_ENDPOINT=$OPENSEARCH_ENDPOINT
OPENSEARCH_DASHBOARD_ENDPOINT=$OPENSEARCH_DASHBOARD_ENDPOINT
OPENSEARCH_USERNAME=admin
OPENSEARCH_PASSWORD=$OPENSEARCH_PASSWORD

## IRSA Role Information
DIFY_EE_S3_ROLE_ARN=$DIFY_EE_S3_ROLE_ARN
DIFY_EE_S3_ECR_ROLE_ARN=$DIFY_EE_S3_ECR_ROLE_ARN
DIFY_EE_ECR_PULL_ROLE_ARN=$DIFY_EE_ECR_PULL_ROLE_ARN

## ServiceAccount Information
# For detailed information, see: terraform output dify_ee_service_accounts_info

## Helm Deployment Status
# For detailed information, see: terraform output helm_releases_status

# ========================================
# Deployment Command Reference
# ========================================

## 1. Update kubeconfig
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

## 2. Verify cluster connection
kubectl get nodes

## 3. Add Dify Helm repository
helm repo add dify https://langgenius.github.io/dify-helm
helm repo update

## 4. Deploy using generated values.yaml
# helm upgrade -i dify -f ../secret/$values_file dify/dify  # Commented out - values file not generated

# ========================================
# Important Reminders
# ========================================
# 1. This file contains sensitive information, please handle with care
# 2. Do not commit this file to version control systems
# 3. Consider deleting this file after deployment
# 4. Regularly rotate database passwords and API keys
EOF


    log_success "Configuration files generated successfully:"
    log_success "  - Detailed config: $config_file"
    # log_success "  - Helm Values: $values_file"  # Commented out - values file not generated
    
    # Set file permissions (owner read/write only)
    chmod 600 "$config_file" # "$values_file"  # Commented out - values file not generated
    log_warning "Configuration file permissions set to 600 (owner read/write only)"
}

# Generate deployment script
generate_deployment_script() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local deploy_script="../secret/deploy_dify_${timestamp}.sh"
    local values_file="../secret/dify_values_${timestamp}.yaml"
    
    log_info "Generating deployment script..."
    
    cat > "$deploy_script" << EOF
#!/bin/bash

# Dify Enterprise Edition Automatic Deployment Script
# Generated at: $(date)
# Environment: $ENVIRONMENT

set -e

echo "=========================================="
echo "  Dify Enterprise Edition Deployment Script"
echo "  Environment: $ENVIRONMENT"
echo "  Cluster: $CLUSTER_NAME"
echo "=========================================="

# 1. Update kubeconfig
echo "1. Updating kubeconfig..."
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# 2. Verify cluster connection
echo "2. Verifying cluster connection..."
kubectl get nodes

# 3. Add Dify Helm repository
echo "3. Adding Dify Helm repository..."
helm repo add dify https://langgenius.github.io/dify-helm
helm repo update

# 4. Create namespace (if not exists)
echo "4. Creating Dify namespace..."
kubectl create namespace dify --dry-run=client -o yaml | kubectl apply -f -

# 5. Deploy Dify application
echo "5. Deploying Dify application..."
helm upgrade -i dify -f $values_file dify/dify -n dify

# 6. Wait for deployment completion
echo "6. Waiting for deployment completion..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=dify -n dify --timeout=600s

# 7. Display deployment status
echo "7. Displaying deployment status..."
kubectl get pods -n dify
kubectl get svc -n dify
kubectl get ingress -n dify

echo "=========================================="
echo "  Deployment completed!"
echo "=========================================="
echo
echo "Next steps:"
echo "1. Configure DNS records to point to Load Balancer"
echo "2. Access application: https://console.dify.local"
echo "3. View logs: kubectl logs -f deployment/dify-api -n dify"
echo
EOF

    chmod +x "$deploy_script"
    log_success "Deployment script generated successfully: $deploy_script"
}

# Generate output log function removed - now handled by post_apply.sh
# This avoids creating duplicate out.log files

# Main function
main() {
    echo "=============================================================="
    echo "  Dify Enterprise Edition Deployment Configuration Generator"
    echo "=============================================================="
    echo
    
    # Check Terraform state
    check_terraform_state
    
    # Get Terraform outputs
    get_terraform_outputs
    
    # Get database passwords
    get_database_passwords
    
    echo
    log_info "Starting to generate deployment configuration files..."
    echo
    
    # Generate various configuration files
    generate_dify_config
    # generate_deployment_script  # Commented out - not generating deployment script
    # generate_output_log  # Removed - now handled by post_apply.sh to avoid duplicate out.log files
    
    echo
    log_success "All configuration files generated successfully!"
    echo
    echo "Generated files:"
    echo "  - ../secret/dify_deployment_config_*.txt  (Detailed configuration information)"
    # echo "  - ../secret/dify_values_*.yaml           (Helm Values configuration)"  # Commented out - not generated
    # echo "  - ../secret/deploy_dify_*.sh             (Automatic deployment script)"  # Commented out - not generated
    echo "  - ../secret/out_*.log                    (Terraform output log - generated by post_apply.sh)"
    echo
    log_warning "Important reminders:"
    echo "  1. These files contain sensitive information, please handle with care"
    echo "  2. Do not commit these files to version control systems"
    echo "  3. Please modify default keys and domains before deployment"
    echo "  4. Please delete sensitive files securely after use"
    echo
    echo "Next steps:"
    echo "  1. Create your own Helm values.yaml file based on the configuration information"
    # echo "  2. Run deployment script: ../secret/deploy_dify_*.sh"  # Commented out - script not generated
    echo "  2. Deploy manually using Helm with your custom values file"
    # echo "  3. Or deploy manually: helm upgrade -i dify -f ../secret/dify_values_*.yaml dify/dify"  # Commented out - values file not generated
    echo
}

# Run main function
main "$@"