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
resource "aws_instance" "myawsserver" {
  ami = "ami-0ba8711e0e1da2a52"
  instance_type = "t2.micro"
  key_name = "durga-import"

  tags = {
    Name = "durga-DevOps-batch-server"
    env = "Production"
    owner = "Durga"
  }
  provisioner "local-exec" {
    command = "echo The servers IP address is ${self.public_ip} && echo ${self.public_ip} > /tmp/inv"
  }
}
