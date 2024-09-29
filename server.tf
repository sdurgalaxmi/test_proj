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

# Generate the SSH key pair
resource "tls_private_key" "k8s_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Input the existing VPC ID (replace with the actual VPC ID)
variable "existing_vpc_id" {
  description = "ID of the existing VPC"
  default     = "vpc-0b30226ed9787e925"
}

resource "aws_subnet" "k8s_subnet" {
  vpc_id     = var.existing_vpc_id
  cidr_block = "10.0.4.0/24"
  map_public_ip_on_launch = true  # Enable Auto-Assign Public IP

  tags = {
    Name = "demo-k8s-subnet"
  }
}

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = var.existing_vpc_id

  tags = {
    Name = "demo-k8s-igw"
  }
}

resource "aws_route_table" "k8s_route_table" {
  vpc_id = var.existing_vpc_id

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

resource "aws_security_group" "allow_ssh" {
  name        = "durga_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = var.existing_vpc_id 

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


# Store the private key locally on the base node
resource "local_file" "k8s_private_key" {
  filename = "/root/terraform/k8s_ssh_key.pem"
  content  = tls_private_key.k8s_ssh_key.private_key_pem

  # Set proper file permissions for the private key
  file_permission = "0600"
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

# Create an SSH public key to associate with the EC2 instances
resource "aws_key_pair" "k8s_ssh_key" {
  key_name   = "k8s_ssh_key"
  public_key = tls_private_key.k8s_ssh_key.public_key_openssh
}

# Output the private key path and instance information
output "private_key_path" {
  value = local_file.k8s_private_key.filename
}

output "master_ip" {
  value = aws_instance.k8s_master.public_ip
}

output "worker_ips" {
  value = aws_instance.k8s_worker[*].public_ip
}

# Create the inventory content
locals {
  master_ip = aws_instance.k8s_master.public_ip

  worker_ips = join("\n", [for worker in aws_instance.k8s_worker : "${worker.public_ip} ansible_ssh_user=ubuntu"])
  
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
