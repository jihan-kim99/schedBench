provider "aws" {
  region = "us-west-1"
}

module "cluster" {
  source       = "weibeld/kubeadm/aws"
  version      = "0.2.6"
  cluster_name = "jolp"

}
