resource "aws_vpc" "main" {
  cidr_block           = "10.2.0.0/22"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.env}-eks-vpc"
    # EKS uses this tag to discover the VPC
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })
}

# Public subnets: ALB and NAT Gateway live here
resource "aws_subnet" "public" {
  for_each = {
    a = { cidr = "10.2.0.0/24", az = "ap-southeast-1a" }
    b = { cidr = "10.2.1.0/24", az = "ap-southeast-1b" }
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.env}-eks-public-${each.key}"
    # Required for AWS Load Balancer Controller to provision public ALBs/NLBs
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })
}

# Private subnets: EKS nodes live here
resource "aws_subnet" "private" {
  for_each = {
    a = { cidr = "10.2.2.0/24", az = "ap-southeast-1a" }
    b = { cidr = "10.2.3.0/24", az = "ap-southeast-1b" }
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(local.common_tags, {
    Name = "${var.env}-eks-private-${each.key}"
    # Required for AWS Load Balancer Controller to provision internal ALBs/NLBs
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${var.env}-eks-igw" })
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.env}-eks-nat-eip" })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["a"].id
  tags          = merge(local.common_tags, { Name = "${var.env}-eks-nat-gw" })
  depends_on    = [aws_internet_gateway.gw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = merge(local.common_tags, { Name = "${var.env}-eks-public-rt" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = merge(local.common_tags, { Name = "${var.env}-eks-private-rt" })
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
