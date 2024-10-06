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

      # #prom-graf install
      # curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
      # helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
      # helm repo add grafana https://grafana.github.io/helm-charts
      # helm repo update
      # kubectl create namespace monitoring
      # helm install prometheus prometheus-community/prometheus --namespace monitoring
      # helm install grafana grafana/grafana --namespace monitoring
      # kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

      echo '
      (\(\ 
      ( -.-)
      o_(")(")
      '

      echo "All done!"
      EOF
  }
}
