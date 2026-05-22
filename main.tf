terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}


resource "aws_security_group" "zabbix_sg" {
  name        = "zabbix_infrastructure_sg"
  description = "Allow inbound traffic for Zabbix and SSH"


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # trivy:ignore:AVD-AWS-0104
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 10051
    to_port     = 10051
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    # trivy:ignore:AVD-AWS-0107
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "zabbix_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }



  vpc_security_group_ids = [aws_security_group.zabbix_sg.id]


  key_name = "cd-github"


  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y


              apt-get install -y ca-certificates curl gnupg
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              chmod a+r /etc/apt/keyrings/docker.gpg

              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null


              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


              usermod -aG docker ubuntu
              

              mkdir -p /opt/zabbix
              chown -R ubuntu:ubuntu /opt/zabbix
              EOF

  tags = {
    Name = "Zabbix-Server"
  }
}


output "server_public_ip" {
  value       = aws_instance.zabbix_server.public_ip
  description = "Use this IP for SERVER_HOST in GitHub Secrets and to access the Zabbix Web UI"
}