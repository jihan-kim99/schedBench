# External data to check if the Kind cluster exists
data "external" "kind_cluster_check" {
  program = ["bash", "-c", <<EOT
    if kind get clusters | grep -q "kind"; then
      echo "{\"exists\": \"true\"}"
    else
      echo "{\"exists\": \"false\"}"
    fi
  EOT
  ]
}

# Create the Kind cluster if it does not exist
resource "null_resource" "create_kind_cluster" {
  count = data.external.kind_cluster_check.result["exists"] == "false" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
      kind create cluster --config kind-cluster.yaml
      ./kubectl_conf.bash
    EOT
  }
}

# Run kubectl_conf.bash if the Kind cluster exists
resource "null_resource" "run_kubectl_conf" {
  count = data.external.kind_cluster_check.result["exists"] == "true" ? 1 : 0

  provisioner "local-exec" {
    command = "./kubectl_conf.bash"
  }
}

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "host" {
  type = string
}

variable "client_certificate" {
  type = string
}

variable "client_key" {
  type = string
}

variable "cluster_ca_certificate" {
  type = string
}

provider "kubernetes" {
  host = var.host

  client_certificate     = base64decode(var.client_certificate)
  client_key             = base64decode(var.client_key)
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}
