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

provider "tls" {}

# Generate a new SSH key pair
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
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

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "demo-k8s-igw"
  }
}

resource "aws_route_table" "k8s_route_table" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "demo-k8s-rt"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }
}

resource "aws_route_table_association" "k8s_route_table_assoc" {
  subnet_id      = aws_subnet.k8s_subnet.id
  route_table_id = aws_route_table.k8s_route_table.id
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


resource "aws_instance" "k8s_master" {
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

resource "aws_instance" "k8s_worker" {
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

# Create an AWS key pair
resource "aws_key_pair" "k8s_key" {
  key_name   = "demo-k8s-key"
  public_key = tls_private_key.k8s_key.public_key_openssh
}

# Save the private key locally
resource "local_file" "private_key" {
  content  = tls_private_key.k8s_key.private_key_pem
  filename = "/root/terraform/key.pem"
}

# Set permissions for the private key
resource "null_resource" "set_key_permissions" {
  depends_on = [local_file.private_key]

  provisioner "local-exec" {
    command = "chmod 400 ${local_file.private_key.filename}"
  }
}

output "master_ip" {
  value = aws_instance.k8s_master.public_ip
}



output "worker_ips" {
  value = aws_instance.k8s_worker[*].public_ip
}

# Create the inventory content
locals {
  master_ip = aws_instance.k8s_master.private_ip

  worker_ips = join("\n", [for worker in aws_instance.k8s_worker : "${worker.private_ip} ansible_ssh_user=ubuntu"])
  
  inventory_content = <<EOT
[k8s_master]
${local.master_ip} ansible_ssh_user=ubuntu

[k8s_workers]
${local.worker_ips}
EOT
}

resource "local_file" "inventory" {
  filename = "/root/terraform/inventory.ini"

  content = local.inventory_content
}
