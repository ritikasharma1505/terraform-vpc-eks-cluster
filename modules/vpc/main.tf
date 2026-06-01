# ======================================================================================
# VPC NETWORKING - VPC, SUBNETS, ROUTE TABLES, IGW, EIP, NAT GATEWAY, ROUTE ASSOCIATIONS
# ======================================================================================

resource "aws_vpc" "eks_vpc" {

  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-prod-vpc"
  }
}


resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}


resource "aws_subnet" "public_subnet_1" {

  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = var.az_1
  map_public_ip_on_launch = true

  tags = {
  Name = "public-subnet-1"

  "kubernetes.io/role/elb" = "1"
  "kubernetes.io/cluster/eks-prod-cluster" = "shared"
}
  depends_on = [aws_vpc.eks_vpc]
}

resource "aws_subnet" "public_subnet_2" {

  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = var.az_2
  map_public_ip_on_launch = true

  tags = {
  Name = "public-subnet-2"

  "kubernetes.io/role/elb" = "1"
  "kubernetes.io/cluster/eks-prod-cluster" = "shared"
}
  depends_on = [aws_vpc.eks_vpc]
}

resource "aws_subnet" "private_subnet_1" {

  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = var.az_1


  tags = {
  Name = "private-subnet-1"

  "kubernetes.io/role/internal-elb" = "1"
  "kubernetes.io/cluster/eks-prod-cluster" = "shared"
}
  depends_on = [aws_vpc.eks_vpc]
}

resource "aws_subnet" "private_subnet_2" {

  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = var.az_2

  tags = {
  Name = "private-subnet-2"

  "kubernetes.io/role/internal-elb" = "1"
  "kubernetes.io/cluster/eks-prod-cluster" = "shared"
}
  depends_on = [aws_vpc.eks_vpc]
}


resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }

  depends_on = [aws_vpc.eks_vpc]
}

resource "aws_route_table_association" "public_subnet_1_assoc" {

  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id

  depends_on = [aws_vpc.eks_vpc, aws_subnet.public_subnet_1 ]
}

resource "aws_route_table_association" "public_subnet_2_assoc" {

  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id

  depends_on = [aws_vpc.eks_vpc, aws_subnet.public_subnet_2]
}

resource "aws_eip" "nat_eip" {

  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }

  depends_on = [aws_vpc.eks_vpc]
}

resource "aws_nat_gateway" "nat_gw" {

  allocation_id = aws_eip.nat_eip.id

  subnet_id = aws_subnet.public_subnet_1.id

  tags = {
    Name = "eks-nat-gateway"
  }

  depends_on = [aws_vpc.eks_vpc, aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {

  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private-route-table"
  }

  depends_on = [aws_vpc.eks_vpc]
}

resource "aws_route_table_association" "private_subnet_1_assoc" {

  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id

  depends_on = [aws_vpc.eks_vpc, aws_subnet.private_subnet_1 ]
}

resource "aws_route_table_association" "private_subnet_2_assoc" {

  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id

  depends_on = [aws_vpc.eks_vpc, aws_subnet.private_subnet_2 ]
}

