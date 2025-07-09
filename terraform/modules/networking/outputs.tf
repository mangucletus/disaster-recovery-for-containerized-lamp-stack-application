output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the VPC"
}

output "public_subnet_ids" {
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  description = "IDs of public subnets"
}

output "private_subnet_ids" {
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  description = "IDs of private subnets"
}

output "nat_gateway_ids" {
  value       = var.create_nat_gateways ? [aws_nat_gateway.nat_1[0].id, aws_nat_gateway.nat_2[0].id] : []
  description = "IDs of NAT gateways"
}