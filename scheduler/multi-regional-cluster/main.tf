terraform {
  required_version = ">= 0.12"
}

# Provider configuration
provider "aws" {
  region = var.primary_region
  alias  = "primary"
}

provider "aws" {
  region = var.secondary_region
  alias  = "secondary"
}

# EC2 Instances
data "aws_ami" "ubuntu_primary" {
  provider    = aws.primary
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_ami" "ubuntu_secondary" {
  provider    = aws.secondary
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Key pair

resource "aws_key_pair" "main" {
  provider        = aws.primary
  key_name_prefix = "${var.cluster_name}-"
  public_key      = file(var.public_key_file)
  tags            = local.tags
}

# Create a replica of the key pair in the secondary region
resource "aws_key_pair" "secondary" {
  provider        = aws.secondary
  key_name_prefix = "${var.cluster_name}-"
  public_key      = file(var.public_key_file)
  tags            = local.tags
}

resource "aws_eip" "master" {
  provider = aws.primary
  domain   = "vpc"
  tags     = local.tags
}

resource "aws_eip_association" "master" {
  provider      = aws.primary
  allocation_id = aws_eip.master.id
  instance_id   = aws_instance.master.id
}

resource "random_string" "token_id" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "token_secret" {
  length  = 16
  special = false
  upper   = false
}

locals {
  token = "${random_string.token_id.result}.${random_string.token_secret.result}"
}

resource "aws_instance" "master" {
  provider      = aws.primary
  ami           = data.aws_ami.ubuntu_primary.image_id
  instance_type = var.master_instance_type
  subnet_id     = aws_subnet.primary.id
  key_name      = aws_key_pair.main.key_name

  root_block_device {
    volume_size = 40
  }
  vpc_security_group_ids = [
    aws_security_group.egress.id,
    aws_security_group.ingress_internal.id,
    aws_security_group.ingress_k8s.id,
    aws_security_group.ingress_ssh.id
  ]
  tags = merge(local.tags, { "terraform-kubeadm:node" = "master" })
  user_data = templatefile(
    "${path.module}/user-data.tftpl",
    {
      node              = "master",
      token             = local.token,
      cidr              = var.pod_network_cidr_block
      master_public_ip  = aws_eip.master.public_ip,
      master_private_ip = null,
      worker_index      = null,
    }
  )
}

resource "aws_instance" "workers_primary" {
  count                       = var.num_workers / 2
  provider                    = aws.primary
  ami                         = data.aws_ami.ubuntu_primary.image_id
  instance_type               = var.worker_instance_type
  subnet_id                   = aws_subnet.primary.id
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.egress.id,
    aws_security_group.ingress_internal.id,
    aws_security_group.ingress_ssh.id
  ]
  root_block_device {
    volume_size = var.volume_size
  }
  tags = merge(local.tags, {
    "terraform-kubeadm:node"        = "worker-primary-${count.index}",
    "topology.kubernetes.io/region" = var.primary_region
    "topology.kubernetes.io/zone"   = "${var.primary_region}a"
  })
  user_data = templatefile(
    "${path.module}/user-data.tftpl",
    {
      node              = "worker",
      token             = local.token,
      cidr              = var.pod_network_cidr_block,
      master_public_ip  = null,
      master_private_ip = aws_instance.master.private_ip,
      worker_index      = count.index
    }
  )
}

resource "aws_instance" "workers_secondary" {
  count                       = var.num_workers - (var.num_workers / 2)
  provider                    = aws.secondary
  ami                         = data.aws_ami.ubuntu_secondary.image_id
  instance_type               = var.worker_instance_type
  subnet_id                   = aws_subnet.secondary.id
  key_name                    = aws_key_pair.secondary.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.egress_secondary.id,
    aws_security_group.ingress_internal_secondary.id,
    aws_security_group.ingress_ssh_secondary.id
  ]
  root_block_device {
    volume_size = var.volume_size
  }
  tags = merge(local.tags, {
    "terraform-kubeadm:node"        = "worker-secondary-${count.index}",
    "topology.kubernetes.io/region" = var.secondary_region
    "topology.kubernetes.io/zone"   = "${var.secondary_region}a"
  })
  user_data = templatefile(
    "${path.module}/user-data.tftpl",
    {
      node              = "worker",
      token             = local.token,
      cidr              = var.pod_network_cidr_block,
      master_public_ip  = null,
      master_private_ip = aws_instance.master.private_ip,
      worker_index      = count.index + length(aws_instance.workers_primary)
    }
  )
}
