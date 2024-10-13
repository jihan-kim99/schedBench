resource "aws_vpc" "primary" {
  provider             = aws.primary
  cidr_block           = var.primary_vpc_cidr
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.cluster_name}-primary-vpc" })
}

resource "aws_subnet" "primary" {
  provider          = aws.primary
  vpc_id            = aws_vpc.primary.id
  cidr_block        = var.primary_subnet_cidr
  availability_zone = "${var.primary_region}a"
  tags              = merge(local.tags, { Name = "${var.cluster_name}-primary-subnet" })
}

# Secondary VPC
resource "aws_vpc" "secondary" {
  provider             = aws.secondary
  cidr_block           = var.secondary_vpc_cidr
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.cluster_name}-secondary-vpc" })
}

resource "aws_subnet" "secondary" {
  provider          = aws.secondary
  vpc_id            = aws_vpc.secondary.id
  cidr_block        = var.secondary_subnet_cidr
  availability_zone = "${var.secondary_region}a"
  tags              = merge(local.tags, { Name = "${var.cluster_name}-secondary-subnet" })
}

resource "aws_vpc" "third" {
  provider             = aws.third
  cidr_block           = var.third_vpc_cidr
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.cluster_name}-third-vpc" })
}

resource "aws_subnet" "third" {
  provider          = aws.third
  vpc_id            = aws_vpc.third.id
  cidr_block        = var.third_subnet_cidr
  availability_zone = "${var.third_region}a"
  tags              = merge(local.tags, { Name = "${var.cluster_name}-third-subnet" })
}

resource "aws_vpc_peering_connection" "primary_to_secondary" {
  provider    = aws.primary
  vpc_id      = aws_vpc.primary.id
  peer_vpc_id = aws_vpc.secondary.id
  peer_region = var.secondary_region
  tags        = merge(local.tags, { Name = "${var.cluster_name}-vpc-peering" })
}

resource "aws_vpc_peering_connection" "primary_to_third" {
  provider    = aws.primary
  vpc_id      = aws_vpc.primary.id
  peer_vpc_id = aws_vpc.third.id
  peer_region = var.third_region
  tags        = merge(local.tags, { Name = "${var.cluster_name}-vpc-peering-primary-to-third" })
}

resource "aws_vpc_peering_connection" "secondary_to_third" {
  provider    = aws.secondary
  vpc_id      = aws_vpc.secondary.id
  peer_vpc_id = aws_vpc.third.id
  peer_region = var.third_region
  tags        = merge(local.tags, { Name = "${var.cluster_name}-vpc-peering-secondary-to-third" })
}

resource "aws_vpc_peering_connection_accepter" "secondary" {
  provider                  = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  auto_accept               = true

  tags = merge(local.tags, { Name = "${var.cluster_name}-vpc-peering-accepter" })
}

resource "aws_vpc_peering_connection_accepter" "third" {
  provider                  = aws.third
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_third.id
  auto_accept               = true

  tags = merge(local.tags, { Name = "${var.cluster_name}-vpc-peering-accepter" })
}

resource "aws_vpc_peering_connection_accepter" "third_from_secondary" {
  provider                  = aws.third
  vpc_peering_connection_id = aws_vpc_peering_connection.secondary_to_third.id
  auto_accept               = true

  tags = merge(local.tags, { Name = "${var.cluster_name}-vpc-peering-accepter-third-from-secondary" })
}

# Route tables for VPC Peering
resource "aws_route_table" "primary" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  route {
    cidr_block                = var.secondary_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  }
  route {
    cidr_block                = var.third_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_third.id
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary.id
  }
  tags = merge(local.tags, { Name = "${var.cluster_name}-primary-route-table" })
}

# Route Tables for Secondary VPC
resource "aws_route_table" "secondary" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id
  route {
    cidr_block                = var.primary_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  }
  route {
    cidr_block                = var.third_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.secondary_to_third.id
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary.id
  }
  tags = merge(local.tags, { Name = "${var.cluster_name}-secondary-route-table" })
}

resource "aws_route_table" "third" {
  provider = aws.third
  vpc_id   = aws_vpc.third.id
  route {
    cidr_block                = var.primary_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_third.id
  }
  route {
    cidr_block                = var.secondary_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.secondary_to_third.id
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.third.id
  }
  tags = merge(local.tags, { Name = "${var.cluster_name}-third-route-table" })
}

resource "aws_route_table_association" "primary" {
  provider       = aws.primary
  subnet_id      = aws_subnet.primary.id
  route_table_id = aws_route_table.primary.id
}

resource "aws_route_table_association" "secondary" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary.id
  route_table_id = aws_route_table.secondary.id
}

resource "aws_route_table_association" "third" {
  provider       = aws.third
  subnet_id      = aws_subnet.third.id
  route_table_id = aws_route_table.third.id
}

# Internet Gateway for Primary VPC
resource "aws_internet_gateway" "primary" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  tags     = merge(local.tags, { Name = "${var.cluster_name}-primary-igw" })
}

# Internet Gateway for Secondary VPC
resource "aws_internet_gateway" "secondary" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id
  tags     = merge(local.tags, { Name = "${var.cluster_name}-secondary-igw" })
}

resource "aws_internet_gateway" "third" {
  provider = aws.third
  vpc_id   = aws_vpc.third.id
  tags     = merge(local.tags, { Name = "${var.cluster_name}-third-igw" })

}
