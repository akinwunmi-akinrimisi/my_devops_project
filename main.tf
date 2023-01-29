provider "aws" {
  region = var.aws_region
}

 data "aws_ssm_parameter" "instance_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# Creating the VPC
resource "aws_vpc" "servers_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "servers_vpc"
  }
}

# Creating the Internet Gateway
resource "aws_internet_gateway" "servers_igw" {
  vpc_id = aws_vpc.servers_vpc.id
  tags = {
    Name = "servers_igw"
  }
}

# Creating the public subnet
resource "aws_subnet" "servers_public_subnet" {
  vpc_id                  = aws_vpc.servers_vpc.id
  cidr_block              = var.servers_public_subnet_cidr_block[0]
  availability_zone       = var.availability_zone[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "servers_public_subnet"
  }
}

# Creating the public route table
resource "aws_route_table" "servers_public_rt" {
  vpc_id = aws_vpc.servers_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.servers_igw.id
  }
}


# Associating our public subnet with our public route table
resource "aws_route_table_association" "servers_public" {
  route_table_id = aws_route_table.servers_public_rt.id
  subnet_id      = aws_subnet.servers_public_subnet.id
}


# Creating a security group for the Jenkins server
resource "aws_security_group" "servers_sg" {
  name        = "servers_sg"
  description = "Security group for jenkins server"
  vpc_id      = aws_vpc.servers_vpc.id

  ingress {
    description = "allow anyone on port 22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow anyone on port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow anyone on port 8080"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow anyone on port 8080"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "servers_sg"
  }
}

# Creating an EC2 instance called cba_jenkins_server
resource "aws_instance" "cba_jenkins_server" {
  ami                    = data.aws_ssm_parameter.instance_ami.value
  subnet_id              = aws_subnet.servers_public_subnet.id
  instance_type          = var.instance_type[0]
  vpc_security_group_ids = [aws_security_group.servers_sg.id]
  key_name               = var.aws_key_pair[0]
  user_data              = fileexists("install_jenkins.sh") ? file("install_jenkins.sh") : null
  tags = {
    Name = "cba_jenkins_server"
  }
}


# Creating an Elastic IP called jenkins_eip
resource "aws_eip" "cba_jenkins_eip" {
  instance = aws_instance.cba_jenkins_server.id
  vpc      = true
  tags = {
    Name = "jenkins_eip"
  }
}


# Creating the 2nd public subnet
resource "aws_subnet" "servers_public_subnet_02" {
  vpc_id                  = aws_vpc.servers_vpc.id
  cidr_block              = var.servers_public_subnet_cidr_block[1]
  availability_zone       = var.availability_zone[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "servers_public_subnet_02"
  }
}

# Creating the public route table
resource "aws_route_table" "servers_public_rt_02" {
  vpc_id = aws_vpc.servers_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.servers_igw.id
  }
}


# Associating our public subnet with our public route table
resource "aws_route_table_association" "servers_public_02" {
  route_table_id = aws_route_table.servers_public_rt_02.id
  subnet_id      = aws_subnet.servers_public_subnet_02.id
}


# Creating a 2nd EC2 instance called cba_jenkins_server_02
resource "aws_instance" "cba_jenkins_server_02" {
  ami                    = data.aws_ssm_parameter.instance_ami.value
  subnet_id              = aws_subnet.servers_public_subnet_02.id
  instance_type          = var.instance_type[0]
  vpc_security_group_ids = [aws_security_group.servers_sg.id]
  key_name               = var.aws_key_pair[0]
  user_data              = fileexists("install_jenkins.sh") ? file("install_jenkins.sh") : null
  tags = {
    Name = "cba_jenkins_server_02"
  }
}


#Creating webservers in 1st AZ
resource "aws_instance" "cba_webserver_01" {
  ami                    = data.aws_ssm_parameter.instance_ami.value
  subnet_id              = aws_subnet.servers_public_subnet.id
  instance_type          = var.instance_type[0]
  count                  = 2
  vpc_security_group_ids = [aws_security_group.servers_sg.id]
  key_name               = var.aws_key_pair[0]
  tags = {
    Name = "cba_webserver01"
  }
}

#Creating a webserver in 2nd AZ
resource "aws_instance" "cba_webserver" {
  ami                    = data.aws_ssm_parameter.instance_ami.value
  subnet_id              = aws_subnet.servers_public_subnet_02.id
  instance_type          = var.instance_type[0]
  count                  = 2
  vpc_security_group_ids = [aws_security_group.servers_sg.id]
  key_name               = var.aws_key_pair[0]
  tags = {
    Name = "cba_webserver"
  }
}