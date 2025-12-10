resource "aws_internet_gateway" "demogateway" {
    vpc_id = var.vpc
  
}