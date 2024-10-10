
resource "aws_security_group" "egress" {
  provider    = aws.primary
  name        = "${var.cluster_name}-egress"
  description = "Allow all outgoing traffic to everywhere"
  vpc_id      = aws_vpc.primary.id
  tags        = local.tags
  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "egress_secondary" {
  provider    = aws.secondary
  name        = "${var.cluster_name}-egress-secondary"
  description = "Allow all outgoing traffic to everywhere"
  vpc_id      = aws_vpc.secondary.id
  tags        = local.tags
  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "egress_third" {
  provider    = aws.third
  name        = "${var.cluster_name}-egress-third"
  description = "Allow all outgoing traffic to everywhere"
  vpc_id      = aws_vpc.third.id
  tags        = local.tags
  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress_internal" {
  provider    = aws.primary
  name        = "${var.cluster_name}-ingress-internal"
  description = "Allow all incoming traffic from nodes and Pods in the cluster"
  vpc_id      = aws_vpc.primary.id
  tags        = local.tags
  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.primary_vpc_cidr, var.secondary_vpc_cidr, var.third_vpc_cidr]
    description = "Allow incoming traffic from cluster nodes in all regions"
  }
  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = var.pod_network_cidr_block != null ? [var.pod_network_cidr_block] : null
    description = "Allow incoming traffic from the Pods of the cluster"
  }
  ingress {
    protocol    = "udp"
    from_port   = 8285
    to_port     = 8285
    cidr_blocks = [var.primary_vpc_cidr, var.secondary_vpc_cidr, var.third_vpc_cidr]
    description = "Allow Flannel VXLAN"
  }
  ingress {
    protocol    = "udp"
    from_port   = 8472
    to_port     = 8472
    cidr_blocks = [var.primary_vpc_cidr, var.secondary_vpc_cidr, var.third_vpc_cidr]
    description = "Allow Flannel VXLAN"
  }
}

resource "aws_security_group" "ingress_k8s" {
  provider    = aws.primary
  name        = "${var.cluster_name}-ingress-k8s"
  description = "Allow incoming Kubernetes API requests (TCP/6443) from outside the cluster"
  vpc_id      = aws_vpc.primary.id
  tags        = local.tags
  ingress {
    protocol    = "tcp"
    from_port   = 6443
    to_port     = 6443
    cidr_blocks = var.allowed_k8s_cidr_blocks
  }
}

resource "aws_security_group" "ingress_ssh" {
  provider    = aws.primary
  name        = "${var.cluster_name}-ingress-ssh"
  description = "Allow incoming SSH traffic (TCP/22) from outside the cluster"
  vpc_id      = aws_vpc.primary.id
  tags        = local.tags
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }
}

resource "aws_security_group" "ingress_internal_secondary" {
  provider    = aws.secondary
  name        = "${var.cluster_name}-ingress-internal"
  description = "Allow all incoming traffic from nodes and Pods in the cluster"
  vpc_id      = aws_vpc.secondary.id
  tags        = local.tags
  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.primary_vpc_cidr, var.secondary_vpc_cidr, var.third_vpc_cidr]
    description = "Allow incoming traffic from cluster nodes in all regions"
  }
  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = var.pod_network_cidr_block != null ? [var.pod_network_cidr_block] : null
    description = "Allow incoming traffic from the Pods of the cluster"
  }
  ingress {
    protocol    = "udp"
    from_port   = 8285
    to_port     = 8285
    cidr_blocks = [var.primary_vpc_cidr, var.secondary_vpc_cidr, var.third_vpc_cidr]
    description = "Allow Flannel VXLAN"
  }
  ingress {
    protocol    = "udp"
    from_port   = 8472
    to_port     = 8472
    cidr_blocks = [var.primary_vpc_cidr, var.secondary_vpc_cidr, var.third_vpc_cidr]
    description = "Allow Flannel VXLAN"
  }
}

resource "aws_security_group" "ingress_ssh_secondary" {
  provider    = aws.secondary
  name        = "${var.cluster_name}-ingress-ssh"
  description = "Allow incoming SSH traffic (TCP/22) from outside the cluster"
  vpc_id      = aws_vpc.secondary.id
  tags        = local.tags
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }
}

resource "aws_security_group" "ingress_internal_third" {
  provider    = aws.third
  name        = "${var.cluster_name}-ingress-internal"
  description = "Allow all incoming traffic from nodes and Pods in the cluster"
  vpc_id      = aws_vpc.third.id
  tags        = local.tags
  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.primary_vpc_cidr, var.secondary_vpc_cidr, var.third_vpc_cidr]
    description = "Allow incoming traffic from cluster nodes in all regions"
  }
  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = var.pod_network_cidr_block != null ? [var.pod_network_cidr_block] : null
    description = "Allow incoming traffic from the Pods of the cluster"
  }
  ingress {
    protocol    = "udp"
    from_port   = 8285
    to_port     = 8285
    cidr_blocks = [var.primary_vpc_cidr, var.secondary_vpc_cidr, var.third_vpc_cidr]
    description = "Allow Flannel VXLAN"
  }
  ingress {
    protocol    = "udp"
    from_port   = 8472
    to_port     = 8472
    cidr_blocks = [var.primary_vpc_cidr, var.secondary_vpc_cidr, var.third_vpc_cidr]
    description = "Allow Flannel VXLAN"
  }
}

resource "aws_security_group" "ingress_ssh_third" {
  provider    = aws.third
  name        = "${var.cluster_name}-ingress-ssh"
  description = "Allow incoming SSH traffic (TCP/22) from outside the cluster"
  vpc_id      = aws_vpc.third.id
  tags        = local.tags
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }
}
