terraform {
  backend "s3" {
    bucket         = "test-eks-cluster-terraform-state"
    key            = "dify-enterprise/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "test-eks-cluster-terraform-locks"
    encrypt        = true
  }
}