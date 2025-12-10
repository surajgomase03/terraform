

output "vpc" {
  value = aws_vpc.demovpc.id 
}

output "public" {
  value = aws_subnet.demopublicsubnet.id
  
}