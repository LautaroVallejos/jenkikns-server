data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "jenkins-server"

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer.id
  user_data = "${file("install_docker.sh")}"
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.firewall.id]
  subnet_id              = aws_subnet.test-network.id

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }

  provisioner "file" {
    source = "./docker-compose.yml"
    destination = "~/docker-compose.yml"
  }
}

resource "null_resource" "this" {
  provisioner "file" {
    source      = "./foo.txt"
    destination = "/home/ec2-user/foo.txt"
    connection {
        type        = "ssh"
        user        = "ubuntu"
        private_key = "${file("./.keys/server-key")}"
        host        = module.ec2.public_dns
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block       = "18.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "Server-Network"
  }
}

resource "aws_subnet" "test-network" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "18.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "Main"
  }
}

resource "aws_security_group" "firewall" {
  name        = "server-firewall"
  description = "security group for jenkins test server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 21
    to_port          = 21
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = "${file("./.keys/server-key.pub")}"
}