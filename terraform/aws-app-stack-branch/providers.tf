terraform {
  required_version = ">= 1.4.0"

  required_providers {
    volterra = {
      source = "volterraedge/volterra"
      version = "=0.11.22"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "=4.67.0"
    }
  }
}

provider "volterra" {
  api_p12_file = var.xc_api_p12_file
  url          = var.xc_api_url
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}