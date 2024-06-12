terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

# Uses env vars for secrets
provider "aws" {
  region  = "us-west-2"
}

# Fetch existing public key from env var 
variable "PUB_KEY" {
  type = string
}

resource "aws_key_pair" "minecraft" {
  key_name   = "deployer-key"
  public_key = var.PUB_KEY
}


resource "aws_vpc" "minecraft" {
  provider = aws
  enable_dns_support = true
  enable_dns_hostnames = true
  assign_generated_ipv6_cidr_block = true
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "minecraft" {
    vpc_id            = "${aws_vpc.minecraft.id}"
    availability_zone = "us-west-2a"
    cidr_block        = "${cidrsubnet(aws_vpc.minecraft.cidr_block, 4, 1)}"
    map_public_ip_on_launch = true
    
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.minecraft.ipv6_cidr_block, 8, 1)}"
    assign_ipv6_address_on_creation = true
}

resource "aws_internet_gateway" "minecraft" {
    provider = aws
    vpc_id = "${aws_vpc.minecraft.id}"
}

resource "aws_default_route_table" "minecraft" {
    provider = aws
    default_route_table_id = "${aws_vpc.minecraft.default_route_table_id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.minecraft.id}"
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id = "${aws_internet_gateway.minecraft.id}"
    }
}

resource "aws_route_table_association" "minecraft" {
    provider = aws
    subnet_id      = "${aws_subnet.minecraft.id}"
    route_table_id = "${aws_default_route_table.minecraft.id}"
}

# Allow ssh and minecraft tcp
resource "aws_security_group" "minecraft" {
  provider = aws
  vpc_id = "${aws_vpc.minecraft.id}"
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description = "Minecraft"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Minecraft"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    description = ""
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = ""
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "Minecraft"
  }
}



resource "aws_instance" "minecraft_server" {
  ami = "ami-0423fca164888b941"
  instance_type = "t2.medium"
  key_name = aws_key_pair.minecraft.key_name
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.minecraft.id}"
  ipv6_address_count = 1
  vpc_security_group_ids = [aws_security_group.minecraft.id]

  tags = {
    Name = "minecraft"
  }
}
