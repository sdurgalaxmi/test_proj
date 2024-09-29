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



resource "aws_instance" "master" {
  ami           = "ami-085f9c64a9b75eed5"  # Change to your preferred AMI (e.g., Ubuntu)
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.k8s_subnet.id
  security_groups = [aws_security_group.k8s_sg.name]

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
  security_groups = [aws_security_group.k8s_sg.name]

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
