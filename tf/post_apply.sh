#!/bin/bash

# Terraform Apply Post-processing Script
# Automatically generate configuration files required for Dify deployment

set -e


# Check terraform state
if [ ! -f "terraform.tfstate" ]; then
    echo "Error: terraform.tfstate file not found"
    exit 1
fi

echo "✅ Terraform state file exists"

# Generate output log with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_LOG_FILE="../secret/out_${TIMESTAMP}.log"

# Ensure secret directory exists
mkdir -p "../secret"

echo "📝 Generating output log..."
{
    echo "# Terraform Output Log"
    echo "# Generated at: $(date)"
    echo "# ========================================"
    echo
    terraform output
    echo
    echo "# ========================================"
    echo "# Sensitive Information"
    echo "# ========================================"
    echo
    # Extract passwords from configuration files
    if [ -f "rds.tf" ]; then
        RDS_PASSWORD=$(grep "master_password" rds.tf | sed 's/.*= *"\([^"]*\)".*/\1/' | head -1 || echo "DifyRdsPassword123!")
        echo "RDS_PASSWORD = \"$RDS_PASSWORD\""
    fi
    
    if [ -f "opensearch.tf" ]; then
        OPENSEARCH_PASSWORD=$(grep "master_password" opensearch.tf | sed 's/.*= *"\([^"]*\)".*/\1/' | head -1 || echo "DifyOpenSearch123!")
        echo "OPENSEARCH_PASSWORD = \"$OPENSEARCH_PASSWORD\""
    fi

    echo
    echo "# =========================================="
    echo "# IRSA Role ARNs (for Helm values annotations)"
    echo "# =========================================="
    S3_ROLE_ARN=$(terraform output -raw dify_ee_s3_role_arn 2>/dev/null || echo "N/A")
    S3_ECR_ROLE_ARN=$(terraform output -raw dify_ee_s3_ecr_role_arn 2>/dev/null || echo "N/A")
    ECR_PULL_ROLE_ARN=$(terraform output -raw dify_ee_ecr_pull_role_arn 2>/dev/null || echo "N/A")
    echo "DIFY_EE_S3_ROLE_ARN = \"$S3_ROLE_ARN\""
    echo "DIFY_EE_S3_ECR_ROLE_ARN = \"$S3_ECR_ROLE_ARN\""
    echo "DIFY_EE_ECR_PULL_ROLE_ARN = \"$ECR_PULL_ROLE_ARN\""
    
} > "$OUTPUT_LOG_FILE"

chmod 600 "$OUTPUT_LOG_FILE"
echo "✅ Output log generated: $OUTPUT_LOG_FILE"

# Run configuration generation script
if [ -f "generate_dify_config.sh" ]; then
    echo "🚀 Running Dify configuration generation script..."
    ./generate_dify_config.sh
else
    echo "⚠️  generate_dify_config.sh script not found"
fi

echo "Generated files:"
echo "  - $OUTPUT_LOG_FILE                      (Terraform output log)"
echo "  - dify_deployment_config_*.txt (Dify deployment configuration)"
# echo "  - dify_values_*.yaml          (Helm Values files)"
# echo "  - deploy_dify_*.sh            (Automated deployment scripts)"
echo
echo "Next steps:"
echo "  1. Check generated files and create values.yaml"
echo "  2. Modify domain and secrets in values.yaml"
echo "  3. Run helm upgrade -i dify -f values.yaml dify/dify -n dify to deploy Dify (note: install in dify namespace, not default)"
echo