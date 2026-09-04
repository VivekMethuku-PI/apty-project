terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "apty-env-banner"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type    = string
  default = "Dev"
}

module "site" {
  source = "../../modules/static-site"

  name_prefix        = "apty-env-banner"
  environment        = var.environment
  page_template_path = "${path.root}/../../../app/index.html.tmpl"
}

output "cloudfront_url" {
  value = module.site.cloudfront_url
}
