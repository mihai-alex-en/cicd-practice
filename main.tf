provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "main-igw" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/.ssh/terraform_rsa"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${path.module}/.ssh/terraform_rsa.pub"
  file_permission = "0644"
}

resource "aws_key_pair" "deployer" {
  key_name   = "ubuntu_ssh_key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "aws_security_group" "allow_web" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "allow-web" }
}

resource "aws_instance" "ubuntu_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_web.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y nginx
              echo "<h1>Hello From Ubuntu EC2 Instance</h1>" > /var/www/html/index.html
              sed -i 's/listen 80 default_server;/listen 8080 default_server;/' /etc/nginx/sites-available/default
              systemctl restart nginx
              EOF

  tags = { Name = "ubuntu-instance" }
}
