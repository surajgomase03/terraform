resource "aws_instance" "example" {
  ami = "ami-0b8d527345fdace59"
  instance_type = "t2.micro"
  subnet_id = var.public
  tags = {
    Name = "ExampleInstance"
  }
  
}