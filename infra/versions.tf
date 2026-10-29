terraform {
  backend "s3" {
    bucket       = "notes-tfstate-397614038828"
    key          = "infra/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }

  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "clj-notes-platform"
      ManagedBy = "terraform"
    }
  }
}