# Networking Module - Creates VPC, Subnets, Routes, NAT Gateways, etc.
# This module can be reused for both primary and DR regions

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    Region      = var.aws_region
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# Get Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Create Public Subnet 1
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-1"
    Environment = var.environment
    Type        = "Public"
  }
}

# Create Public Subnet 2
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-2"
    Environment = var.environment
    Type        = "Public"
  }
}

# Create Private Subnet 1
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.project_name}-private-subnet-1"
    Environment = var.environment
    Type        = "Private"
  }
}

# Create Private Subnet 2
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.project_name}-private-subnet-2"
    Environment = var.environment
    Type        = "Private"
  }
}

# Elastic IPs for NAT Gateways (only in production, not DR)
resource "aws_eip" "nat_1" {
  count  = var.create_nat_gateways ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip-1"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "nat_2" {
  count  = var.create_nat_gateways ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip-2"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways (only in production, not DR to save costs)
resource "aws_nat_gateway" "nat_1" {
  count         = var.create_nat_gateways ? 1 : 0
  allocation_id = aws_eip.nat_1[0].id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name        = "${var.project_name}-nat-gw-1"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "nat_2" {
  count         = var.create_nat_gateways ? 1 : 0
  allocation_id = aws_eip.nat_2[0].id
  subnet_id     = aws_subnet.public_2.id

  tags = {
    Name        = "${var.project_name}-nat-gw-2"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# Private Route Tables
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-private-rt-1"
    Environment = var.environment
  }
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-private-rt-2"
    Environment = var.environment
  }
}

# Routes for Private Route Tables (only if NAT Gateways exist)
resource "aws_route" "private_1_nat" {
  count                  = var.create_nat_gateways ? 1 : 0
  route_table_id         = aws_route_table.private_1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_1[0].id
}

resource "aws_route" "private_2_nat" {
  count                  = var.create_nat_gateways ? 1 : 0
  route_table_id         = aws_route_table.private_2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_2[0].id
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}