resource "null_resource" "wait_for_bootstrap_to_finish" {
  provisioner "local-exec" {
    command = <<-EOF
    alias ssh='ssh -q -i ${var.private_key_file} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    while true; do
      sleep 2
      ! ssh ubuntu@${aws_eip.master.public_ip} [[ -f /home/ubuntu/done ]] >/dev/null && continue
      %{for worker in aws_instance.workers_primary~}
      ! ssh ubuntu@${worker.public_ip} [[ -f /home/ubuntu/done ]] >/dev/null && continue
      %{endfor~}
      echo "workers_primary done"
      %{for worker in aws_instance.workers_secondary~}
      ! ssh ubuntu@${worker.public_ip} [[ -f /home/ubuntu/done ]] >/dev/null && continue
      %{endfor~}
      echo "workers_secondary done"
      %{for worker in aws_instance.workers_third~}
      ! ssh ubuntu@${worker.public_ip} [[ -f /home/ubuntu/done ]] >/dev/null && continue
      %{endfor~}
      echo "workers_third done"
      break
    done
    EOF
  }
  triggers = {
    instance_ids = join(",", concat([aws_instance.master.id], aws_instance.workers_primary[*].id, aws_instance.workers_secondary[*].id, aws_instance.workers_third[*].id))
  }
}

resource "null_resource" "download_kubeconfig_file" {
  provisioner "local-exec" {
    command = <<-EOF
    alias scp='scp -q -i ${var.private_key_file} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    scp ubuntu@${aws_eip.master.public_ip}:/home/ubuntu/admin.conf ${var.kubeconfig != null ? var.kubeconfig : "${var.cluster_name}.conf"} >/dev/null
    EOF
  }
  triggers = {
    wait_for_bootstrap_to_finish = null_resource.wait_for_bootstrap_to_finish.id
  }
}

resource "null_resource" "post_creation" {
  depends_on = [null_resource.download_kubeconfig_file]
  provisioner "local-exec" {
    command = <<-EOF
      echo "Setting KUBECONFIG environment variable..."
      KUBECONFIG=${path.module}/jolp.conf:~/.kube/config kubectl config view --flatten > ~/.kube/config

      echo "Applying Flannel CNI..."
      kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

      echo '
      (\(\ 
      ( -.-)
      o_(")(")
      '
      echo "All done!"
      EOF
  }
}

resource "null_resource" "network-topology" {
  depends_on = [null_resource.post_creation]
  provisioner "local-exec" {
    command = "cd ${path.module}/../network-collector-deployment-aws && terraform apply -auto-approve"
  }
}

# resource "null_resource" "monitoring" {
#   depends_on = [null_resource.post_creation]
#   provisioner "local-exec" {
#     command = "cd ${path.module}/../monitor && terraform apply -auto-approve"
#   }
# }
