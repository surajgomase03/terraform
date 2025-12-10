resource "aws_vpc" "demovpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "demopublicsubnet" {
  vpc_id = aws_vpc.demovpc.id
  availability_zone = "us-east-1a"
  cidr_block = "10.0.1.0/24"
   
    
  
}

