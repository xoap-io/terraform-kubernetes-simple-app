terraform {
  required_providers {
    aws = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
  }
  required_version = ">=1.1.6"
}
