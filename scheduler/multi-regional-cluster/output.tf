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
    }],
    [for i in aws_instance.workers_third : {
      name       = i.tags["terraform-kubeadm:node"]
      subnet_id  = i.subnet_id
      private_ip = i.private_ip
      public_ip  = i.public_ip
      region     = var.third_region
    }]
  )
  description = "Name, public and private IP address, subnet ID, and region of all nodes of the created cluster."
}

output "kubeconfig_path" {
  value       = var.kubeconfig != null ? var.kubeconfig : "${var.cluster_name}.conf"
  description = "Path to the kubeconfig file for the created cluster."
}
