
output "cluster_nodes" {
  value = concat(
    [{
      name       = aws_instance.master.tags["terraform-kubeadm:node"]
      subnet_id  = aws_instance.master.subnet_id
      private_ip = aws_instance.master.private_ip
      public_ip  = aws_eip.master.public_ip
      region     = var.primary_region
    }],
    [for i in aws_instance.workers_primary : {
      name       = i.tags["terraform-kubeadm:node"]
      subnet_id  = i.subnet_id
      private_ip = i.private_ip
      public_ip  = i.public_ip
      region     = var.primary_region
    }],
    [for i in aws_instance.workers_secondary : {
      name       = i.tags["terraform-kubeadm:node"]
      subnet_id  = i.subnet_id
      private_ip = i.private_ip
      public_ip  = i.public_ip
      region     = var.secondary_region
    }]
  )
  description = "Name, public and private IP address, subnet ID, and region of all nodes of the created cluster."
}

output "kubeconfig_path" {
  value       = var.kubeconfig != null ? var.kubeconfig : "${var.cluster_name}.conf"
  description = "Path to the kubeconfig file for the created cluster."
}

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
      %{for worker in aws_instance.workers_secondary~}
      ! ssh ubuntu@${worker.public_ip} [[ -f /home/ubuntu/done ]] >/dev/null && continue
      %{endfor~}
      break
    done
    EOF
  }
  triggers = {
    instance_ids = join(",", concat([aws_instance.master.id], aws_instance.workers_primary[*].id, aws_instance.workers_secondary[*].id))
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
