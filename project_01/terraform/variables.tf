variable "aws_region" {
  default = "us-east-2"
}

variable "availability_zone" {
  type    = list(string)
  default = ["us-east-2a", "us-east-2b"]
}

variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "servers_public_subnet_cidr_block" {
  description = "CIDR block for public subnet"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "instance_type" {
  description = "Instance type"
  type        = list(string)
  default     = ["t2.micro", "t3.medium"]
}

variable "aws_key_pair" {
  description = "keypair for Servers; Jenkins, Ansible & K8s"
  type        = list(string)
  default     = ["Jenkins-keypair-us-east", "Ansible-Server-keypair-us-east-2", "K8s-Server-keypair-us-east-2"]
}