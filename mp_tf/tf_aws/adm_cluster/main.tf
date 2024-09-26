provider "aws" {
  region = "us-west-1"
}

module "cluster" {
  source       = "./modules/cluster"
  cluster_name = "jolp"
}
