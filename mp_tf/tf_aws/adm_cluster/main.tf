provider "aws" {
  region = "us-west-1"
}

module "cluster" {
  source       = "./modules/cluster"
  cluster_name = "jolp"

  master_instance_type = "t3.large"
  num_workers          = 4
  worker_instance_type = "t3.medium"
  volume_size          = 60
}
