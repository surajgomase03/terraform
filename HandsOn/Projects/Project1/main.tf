resource "aws_vpc" "myvpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "myvpc"
    }
}

resource "aws_subnet" "public_subnet1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    tags = {
        Name = "public_subnet1"
    }
    map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    tags = {
        Name = "public_subnet2"
    }
    map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id
    tags = {
        Name = "myigw"
    }
  
}

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.myvpc.id
    tags = {
        Name = "public_rt"
    }
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id

    }
}

resource "aws_route_table_association" "public_subnet1_association" {
    subnet_id      = aws_subnet.public_subnet1.id
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet2_association" {
    subnet_id      = aws_subnet.public_subnet2.id
    route_table_id = aws_route_table.public_rt.id
}


resource "aws_security_group" "my_sg1" {
    vpc_id = aws_vpc.myvpc.id
    name        = "my_sg1"
    description = "Allow SSH and HTTP"
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
}

resource "aws_instance" "myinstance1" {
    ami          = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI (HVM), SSD Volume Type
    instance_type = "t2.micro"
    subnet_id     = aws_subnet.public_subnet1.id
    security_groups = [aws_security_group.my_sg1.name]
    tags = {
        Name = "myec2"
    }
}

resource "aws_instance" "myinstance2" {
    ami          = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI (HVM), SSD Volume Type
    instance_type = "t2.micro"
    subnet_id     = aws_subnet.public_subnet2.id
    security_groups = [aws_security_group.my_sg1.name]
    tags = {
        Name = "myec2"
    }
}


resource "aws_lb" "alb1" {
    name               = "my-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.my_sg1.id]
    subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]

    tags = {
        Name = "my-alb"
    }
  
}

