resource "aws_key_pair" "first_key" {
  key_name = "${var.env}-first_key"
  public_key = file("key.pub")

}

resource "aws_default_vpc" "first_vpc" {
  
}

resource "aws_security_group" "first_sg" {
  name = "${var.env}-sg"
  vpc_id = aws_default_vpc.first_vpc.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
    
  tags = {
    name = "${var.env}-sg"
  }


}



resource "aws_instance" "first_ec2" {
  #count = 2 #meta argumen, multiple resources
  for_each = tomap({
    "first_instance" = "t2.micro"
    "second_instance" = "t3.meduim"
  })
  ami = var.ami_id
  key_name = aws_key_pair.first_key.key_name
  security_groups = [aws_security_group.first_sg]
  #instance_type = "t2.micro"
  instance_type = each.value
  user_data = file("install.sh")


  root_block_device {
    volume_size = 15
    volume_type = "gp3"
  }
  tags = {
    Name = each.key
    #Name = "${var.env}-ec2"
    Env = var.env
  }
  depends_on = [ aws_security_group.first_sg ]
}

output "ec2_public_ip" {
  #outputs for count
  #value = aws_instance.first_ec2[*].public_ip

  # outputs for for_each
   value = [
    for instance in aws_instance.first_ec2 : instace.public_ip
   ]

  
}
output "aws_ec2_dns" {
  value = aws_instance.first_ec2[*].public_dns
  
}