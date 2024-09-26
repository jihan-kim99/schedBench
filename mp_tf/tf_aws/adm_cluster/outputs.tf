resource "null_resource" "set_kubeconfig" {
  provisioner "local-exec" {
    command = "export KUBECONFIG=/home/jihan/schedBench/mp_tf/tf_aws/adm_cluster/jolp.conf"
  }
}
