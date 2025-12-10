# provisioner-demo.tf
# Demonstrates use of provisioners (remote-exec and local-exec).
# Note: Provisioners have drawbacks; prefer cloud-init/config management where possible.

resource "aws_instance" "example" {
  ami           = "ami-0123456789abcdef0"
  instance_type = "t2.micro"
  subnet_id     = ""

  # Example remote-exec (requires SSH connectivity and key)
  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y httpd",
      "sudo systemctl start httpd"
    ]

    # connection block needed for remote-exec (SSH)
    # connection {
    #   type        = "ssh"
    #   user        = "ec2-user"
    #   private_key = file("~/.ssh/id_rsa")
    #   host        = self.public_ip
    # }
  }

  # Example local-exec (runs locally where terraform is executed)
  provisioner "local-exec" {
    command = "echo 'Instance created: ${self.id}' >> created.txt"
  }
}
