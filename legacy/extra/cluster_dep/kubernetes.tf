terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.47.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.4"
    }
  }
}

provider "aws" {
  alias  = "primary"
  region = var.region_primary
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2" # Replace with secondary region
}

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "education-eks-jolp"
}

# Primary region VPC
module "vpc_primary" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "primary-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# Secondary region VPC


module "vpc_secondary" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"
  providers = {
    aws = aws.secondary
  }

  name = "secondary-vpc"

  cidr = "10.1.0.0/16"
  azs  = ["us-west-2a", "us-west-2b"] # Secondary region AZs

  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.3.0/24", "10.1.4.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# Peering between VPCs
resource "aws_vpc_peering_connection" "peer" {
  vpc_id      = module.vpc_primary.vpc_id
  peer_vpc_id = module.vpc_secondary.vpc_id
  peer_region = "us-west-2" # Secondary region
  auto_accept = false

  depends_on = [module.vpc_primary, module.vpc_secondary]
}

resource "aws_vpc_peering_connection_accepter" "peer_accepter" {
  provider                  = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
}

# Add route tables to allow communication between regions
resource "aws_route" "route_to_peer_primary" {
  route_table_id            = module.vpc_primary.private_route_table_ids[0]
  destination_cidr_block    = module.vpc_secondary.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id

  depends_on = [aws_vpc_peering_connection_accepter.peer_accepter]
}

resource "aws_route" "route_to_peer_secondary" {
  route_table_id            = module.vpc_secondary.private_route_table_ids[0]
  destination_cidr_block    = module.vpc_primary.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id

  depends_on = [aws_vpc_peering_connection_accepter.peer_accepter]
}

# EKS Cluster in Primary Region
module "eks_primary" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  vpc_id     = module.vpc_primary.vpc_id
  subnet_ids = module.vpc_primary.private_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Node group in the primary region
  eks_managed_node_groups = {
    primary = {
      name           = "primary-node-group"
      role_arn       = aws_iam_role.eks_worker_role.arn
      instance_types = ["t3.small"]
      min_size       = 3
      max_size       = 3
      desired_size   = 3
    }
    labels = {
      "topology.kubernetes.io/region" = var.region_primary
      "topology.kubernetes.io/zone"   = join("_", module.vpc_primary.azs) # Using underscore instead of comma
    }
  }
  tags = {
    "topology.kubernetes.io/region" = var.region_primary
    "topology.kubernetes.io/zone"   = join("_", module.vpc_primary.azs)
  }
}

module "eks_secondary" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = "${local.cluster_name}-secondary"
  cluster_version = "1.29"

  vpc_id     = module.vpc_secondary.vpc_id
  subnet_ids = module.vpc_secondary.private_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

<<<<<<< Updated upstream:extra/cluster_dep/kubernetes.tf
  eks_managed_node_groups = {
    one = {
      name           = "node-group-1"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      labels = {
        "topology.kubernetes.io/zone"   = "z1"
        "topology.kubernetes.io/region" = "r1"
      }
    }

    two = {
      name           = "node-group-2"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      labels = {
        "topology.kubernetes.io/zone"   = "z2"
        "topology.kubernetes.io/region" = "r1"
      }
    }

    three = {
      name           = "node-group-3"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      labels = {
        "topology.kubernetes.io/zone"   = "z3"
        "topology.kubernetes.io/region" = "r2"
      }
    }

    four = {
      name           = "node-group-4"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      labels = {
        "topology.kubernetes.io/zone"   = "z4"
        "topology.kubernetes.io/region" = "r2"
      }
=======
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Node group in the secondary region
  eks_managed_node_groups = {
    secondary = {
      name           = "secondary-node-group"
      role_arn       = aws_iam_role.eks_worker_role.arn
      instance_types = ["t3.small"]
      min_size       = 3
      max_size       = 3
      desired_size   = 3
    }
    labels = {
      "topology.kubernetes.io/region" = var.region_secondary
      "topology.kubernetes.io/zone"   = join("_", module.vpc_secondary.azs)
>>>>>>> Stashed changes:mp_tf/tf_aws/cluster/kubernetes.tf
    }
  }
  tags = {
    "topology.kubernetes.io/region" = var.region_secondary
    "topology.kubernetes.io/zone"   = join("_", module.vpc_secondary.azs)
  }
}

# IAM Role for Self-Managed Nodes in the Secondary Region
resource "aws_iam_role" "eks_worker_role" {
  name = "eks-worker-role-secondary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_worker_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_worker_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_worker_role.name
}

# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks_primary.cluster_name}"
  provider_url                  = module.eks_primary.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}
