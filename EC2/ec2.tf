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
  ami = var.ami_id
  key_name = aws_key_pair.first_key.key_name
  security_groups = [aws_security_group.first_sg]
  instance_type = "t2.micro"

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
  }
  tags = {
    Name = "${var.env}-ec2"
    Env = var.env
  }
}