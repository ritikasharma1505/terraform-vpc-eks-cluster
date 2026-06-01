terraform {

  required_version = "~> 1.15"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

   backend "s3" {
    bucket         = "terraform-state-bucket-290526"
    key            = "eks/terraform.tfstate"
    region         = "us-east-2"        
    encrypt        = true
    use_lockfile   = true               # s3 state locking

  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

