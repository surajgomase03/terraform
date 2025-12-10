# Application Load Balancer (ALB) example

# Security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP to ALB"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "HTTP"
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

  tags = {
    Name = "alb-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "example-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]

  tags = {
    Name = "example-app-lb"
  }
}

# Target group for the ALB
resource "aws_lb_target_group" "app_tg" {
  name     = "example-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "example-app-tg"
  }
}

# Listener that forwards to the target group
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Example web servers to register with the target group
# Uses a community Amazon Linux 2 AMI via data source

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "web1" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet1.id
  associate_public_ip_address = true

  tags = {
    Name = "web1"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y httpd",
      "sudo systemctl enable httpd",
      "sudo systemctl start httpd",
      "echo \"Hello from web1\" > /var/www/html/index.html"
    ]

    # Note: remote-exec requires connectivity & key; remove or replace if not configured
  }
}

resource "aws_instance" "web2" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet2.id
  associate_public_ip_address = true

  tags = {
    Name = "web2"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y httpd",
      "sudo systemctl enable httpd",
      "sudo systemctl start httpd",
      "echo \"Hello from web2\" > /var/www/html/index.html"
    ]

    # Note: remote-exec requires connectivity & key; remove or replace if not configured
  }
}

# Register instances with the target group
resource "aws_lb_target_group_attachment" "web1_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web2_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}
