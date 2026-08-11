resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/22"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.env}-demo-vpc"
  })
}


resource "aws_subnet" "public-subnet-A" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-southeast-1a"

  tags = merge(local.common_tags, {
    Name = "${var.env}-public-subnet-A"
  })
}

resource "aws_subnet" "public-subnet-B" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1b"

  tags = merge(local.common_tags, {
    Name = "${var.env}-public-subnet-B"
  })
}

resource "aws_subnet" "private-subnet-A" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1a"

  tags = merge(local.common_tags, {
    Name = "${var.env}-private-subnet-A"
  })
}

resource "aws_subnet" "private-subnet-B" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1b"

  tags = merge(local.common_tags, {
    Name = "${var.env}-private-subnet-B"
  })
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.env}-igw"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.env}-nat-eip"
  })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public-subnet-A.id

  tags = merge(local.common_tags, {
    Name = "${var.env}-nat-gw"
  })

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.env}-public-route-table"
  })
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.env}-private-route-table"
  })
}

resource "aws_route_table_association" "public-A" {
  subnet_id      = aws_subnet.public-subnet-A.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_route_table_association" "public-B" {
  subnet_id      = aws_subnet.public-subnet-B.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_route_table_association" "private-A" {
  subnet_id      = aws_subnet.private-subnet-A.id
  route_table_id = aws_route_table.private-route-table.id
}

resource "aws_route_table_association" "private-B" {
  subnet_id      = aws_subnet.private-subnet-B.id
  route_table_id = aws_route_table.private-route-table.id
}
