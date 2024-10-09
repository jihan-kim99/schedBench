provider "aws" {
  region = "us-west-1"
}

module "cluster" {
  source       = "./modules/cluster"
  cluster_name = "jolp"

  master_instance_type = "t3.medium"
  num_workers          = 4
  worker_instance_type = "t3.xlarge"
  volume_size          = 60
}

resource "null_resource" "post_creation" {
  depends_on = [module.cluster]
  provisioner "local-exec" {
    command = <<-EOF
      echo "Setting KUBECONFIG environment variable..."
      KUBECONFIG=/home/jihan/schedBench/mp_tf/tf_aws/adm_cluster/jolp.conf:~/.kube/config kubectl config view --flatten > ~/.kube/config

      # apply flannel network
      kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

      # apply calico
      # kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

      echo '
      (\(\ 
      ( -.-)
      o_(")(")
      '

      echo "All done!"
      EOF
  }
}
