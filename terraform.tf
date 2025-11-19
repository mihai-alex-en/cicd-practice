terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.56"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
  backend "s3" {
    bucket  = "amzn-s3-terraform-state-bucket"
    key     = "cicd-homework-state/terraform.tfstate"
    region  = "eu-north-1"
    encrypt = true
  }
}
