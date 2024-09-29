terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.64.0"
    }
  }
}

provider "aws" {
region = "us-east-2"
}


resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "demo-k8s-vpc"
  }
}

resource "aws_subnet" "k8s_subnet" {
  vpc_id     = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true  # Enable Auto-Assign Public IP


  tags = {
    Name = "demo-k8s-subnet"
  }
}

resource "aws_security_group" "k8s_sg" {
  vpc_id = aws_vpc.k8s_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # http
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict for security in production - https
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Add more ingress rules as necessary for your setup

  tags = {
    Name = "demo-k8s-sg"
  }
} 


resource "aws_instance" "master" {
  ami           = "ami-085f9c64a9b75eed5"  # Change to your preferred AMI (e.g., Ubuntu)
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.k8s_subnet.id
  security_groups = [aws_security_group.k8s_sg.id]
  depends_on = [aws_security_group.k8s_sg]
  associate_public_ip_address = true  # Ensure public IP is assigned

  tags = {
    Name = "demo-k8s-master"
    env = "Production"
    owner = "team2"
  }
}

resource "aws_instance" "worker" {
  count         = 2
  ami           = "ami-085f9c64a9b75eed5"  # Change to your preferred AMI
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.k8s_subnet.id
  security_groups = [aws_security_group.k8s_sg.id]
  depends_on = [aws_security_group.k8s_sg]
  associate_public_ip_address = true  # Ensure public IP is assigned

  tags = {
    Name = "demo-k8s-worker-${count.index}"
    env = "Production"
    owner = "team2"
  }
}

output "master_ip" {
  value = aws_instance.master.public_ip
}

output "worker_ips" {
  value = aws_instance.worker[*].public_ip
}
