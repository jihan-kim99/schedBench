terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.48.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16.1"
    }
  }
}

data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../adm_cluster/terraform.tfstate"
  }
}

provider "kubernetes" {
  config_path = "../adm_cluster/jolp.conf" # Replace with the actual path to your kubeconfig file
}
