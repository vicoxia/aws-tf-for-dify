#!/bin/bash

# Dify Enterprise Database Creation Script (Using RDS Data API)
# This script uses the RDS Data API to create additional databases required for Dify Enterprise Edition.
# No direct network connection to the database is needed; operations are performed via AWS API calls.
# This script will be automatically executed during the terraform build process, no manual execution is required, but you can run it manually if needed.

set -e  # Exit immediately on error


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
    print_info "Checking environment variables..."
    
    required_vars=("CLUSTER_ARN" "SECRET_ARN" "AWS_REGION")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "Environment variable $var is not set"
            exit 1
        fi
    done
    
    print_info "Environment variable check completed"
}

# Check AWS CLI and permissions
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        print_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    print_info "AWS CLI check completed"
}

# Wait for Aurora cluster to be available
wait_for_cluster() {
    print_info "Waiting for Aurora cluster to be available..."
    
    max_attempts=60 # Maximum 60 attempts, 30 seconds each, total maximum wait time about 30 minutes
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        cluster_status=$(aws rds describe-db-clusters \
            --region "$AWS_REGION" \
            --db-cluster-identifier "${CLUSTER_ARN##*/}" \
            --query 'DBClusters[0].Status' \
            --output text 2>/dev/null || echo "not-found")
        
        if [ "$cluster_status" = "available" ]; then
            print_info "Aurora cluster status: available"
            return 0
        else
            print_warning "Aurora cluster status: $cluster_status, waiting... ($attempt/$max_attempts)"
            sleep 30
            ((attempt++))
        fi
    done
    
    print_error "Aurora cluster wait timeout"
    exit 1
}

# Execute SQL using RDS Data API
execute_sql() {
    local sql_statement="$1"
    local database_name="${2:-postgres}"
    
    print_info "Executing SQL: $sql_statement"
    
    local result
    result=$(aws rds-data execute-statement \
        --region "$AWS_REGION" \
        --resource-arn "$CLUSTER_ARN" \
        --secret-arn "$SECRET_ARN" \
        --database "$database_name" \
        --sql "$sql_statement" \
        --output json 2>&1)
    
    if [ $? -eq 0 ]; then
        print_info "SQL execution successful"
        return 0
    else
        print_error "SQL execution failed: $result"
        return 1
    fi
}

# Check if database exists
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
        # Check if the returned records array has data
        local record_count
        record_count=$(echo "$result" | jq '.records | length')
        
        if [ "$record_count" -gt 0 ]; then
            return 0  # Database exists
        else
            return 1  # Database does not exist
        fi
    else
        return 1  # Query failed, assume database does not exist
    fi
}

# Create database function
create_database_if_not_exists() {
    local db_name="$1"
    
    print_info "Checking database: $db_name"
    
    if check_database_exists "$db_name"; then
        print_warning "Database $db_name already exists, skipping creation"
        return 0
    fi
    
    print_info "Creating database: $db_name"
    
    local sql="CREATE DATABASE \"$db_name\";"
    
    if execute_sql "$sql" "postgres"; then
        print_info "Database $db_name created successfully"
        return 0
    else
        print_error "Database $db_name creation failed"
        return 1
    fi
}

# Main function
main() {
    print_info "Starting Dify Enterprise database creation (using RDS Data API)..."
    
    # Check environment variables
    check_env_vars
    
    # Check AWS CLI and permissions
    check_aws_cli
    
    # Wait for cluster to be available
    wait_for_cluster
    
    # Create required databases
    databases=("dify_enterprise" "dify_audit" "dify_plugin_daemon")
    
    failed_databases=()
    
    for db in "${databases[@]}"; do
        if ! create_database_if_not_exists "$db"; then
            failed_databases+=("$db")
        fi
    done
    
    if [ ${#failed_databases[@]} -eq 0 ]; then
        print_info "All databases created successfully!"
        
        # Output connection information
        print_info "Database connection information:"
        echo "  Cluster ARN: $CLUSTER_ARN"
        echo "  Secret ARN: $SECRET_ARN"
        echo "  Region: $AWS_REGION"
        echo "  Created databases:"
        for db in "${databases[@]}"; do
            echo "    - $db"
        done
    else
        print_error "The following databases failed to create: ${failed_databases[*]}"
        exit 1
    fi
}

# Script help information
show_help() {
    cat << EOF
Dify Enterprise Database Creation Script (RDS Data API)

Usage:
    $0 [options]

Environment Variables:
    CLUSTER_ARN  - Aurora cluster ARN (required)
    SECRET_ARN   - ARN of database credentials stored in Secrets Manager (required)
    AWS_REGION   - AWS region (required)

Example:
    export CLUSTER_ARN="arn:aws:rds:us-east-2:123456789012:cluster:my-cluster"
    export SECRET_ARN="arn:aws:secretsmanager:us-east-2:123456789012:secret:rds-db-credentials/cluster-123456/postgres"
    export AWS_REGION="us-east-2"
    $0

Notes:
    - This script uses RDS Data API, no network connection to database required
    - AWS CLI must be configured with appropriate permissions
    - Aurora cluster must have Data API enabled (enable_http_endpoint = true)
    - Database credentials must be stored in AWS Secrets Manager

Options:
    -h, --help   Show this help information

EOF
}

# Handle command line arguments
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
