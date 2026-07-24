#Vpc
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_hostnames = true


  tags = local.vpc_final_tags
}

#Internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = local.igw_final_tags
}

#public subnet
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags,{
    Name = "${var.project}-${var.environment}-public-${local.az_names[count.index]}"
  }, var.public_subnet_tags)
}

#private Subnet
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge(local.common_tags,{
    Name = "${var.project}-${var.environment}-private-${local.az_names[count.index]}"
  }, var.private_subnet_tags)
}

#database subnet
resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = var.database_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge(local.common_tags,{
    Name = "${var.project}-${var.environment}-database-${local.az_names[count.index]}"
  }, var.database_subnet_tags)
}

#route table public

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags,{
    Name = "${var.project}-${var.environment}-public"
  }, var.public_route_table_tags)
}

#route table private

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags,{
    Name = "${var.project}-${var.environment}-private"
  }, var.private_route_table_tags)
}

#route table database

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags,{
    Name = "${var.project}-${var.environment}-database"
  }, var.database_route_table_tags)
}


#adding routes
resource "aws_route" "public" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main.id
}


#eip creation
resource "aws_eip" "nat" {
  domain                    = "vpc"
  tags = merge(local.common_tags,{
    Name = "${var.project}-${var.environment}-nat"
  }, var.eip_tags)

}

#natgateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id #we are creating in us-east-1a availability zone

  tags = merge(local.common_tags,{
    Name = "${var.project}-${var.environment}"
  }, var.nat_gateway_tags)

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main]
}

#adding routes
resource "aws_route" "private" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id
}

#adding routes
resource "aws_route" "database" {
  route_table_id            = aws_route_table.database.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id
}