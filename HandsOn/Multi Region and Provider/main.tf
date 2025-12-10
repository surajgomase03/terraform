resource "aws_vpc" "east_vpc" {
    provider = aws.east
    cidr_block = "10.0.0.0/16"
  
}

resource "aws_default_vpc" "west-vpc" {
    provider = aws.west
    # multiple region provider call using provider= aws.west
}
