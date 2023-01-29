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



######################

resource "aws_security_group" "elb_sg" {
  name        = "elb_sg"
  description = "ELB Security group"
  vpc_id      = aws_vpc.servers_vpc.id

  dynamic "ingress" {
    for_each = var.rules
    content {
      from_port   = ingress.value["port"]
      to_port     = ingress.value["port"]
      protocol    = ingress.value["protocol"]
      cidr_blocks = ingress.value["cidr_blocks"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraformSG"
  }
}

#Creating an Elastic Load Balancer
/* resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    "${aws_security_group.elb_sg.id}"
  ]
  subnets = [
    "${aws_subnet.servers_public_subnet.id}",
    "${aws_subnet.servers_public_subnet_02.id}"
  ]

  cross_zone_load_balancing = true

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:80/"
  }

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "80"
    instance_protocol = "http"
  }

} */


resource "aws_elb" "web_elb" {
  name     = "web_elb"
  internal = false
  security_groups = [
    "${aws_security_group.elb_sg.id}"
  ]
  subnets = [
    "${aws_subnet.servers_public_subnet.id}",
    "${aws_subnet.servers_public_subnet_02.id}"
  ]
  tags = {
    Name = "web_elb-new"
  }
}

  listener = {
    load_balancer_arn = aws_elbv2_load_balancer.web_elb.arn
    protocol          = "HTTP"
    port              = 80
  }

  target_group = {
    name     = "web_elb_target_group"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.servers_vpc.id

    health_check = {
      path                = "/health"
      interval            = 30
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 2
    }
  }

  listener_rule = {
    listener_arn = aws_elbv2_listener.web_elb_listener.arn
    priority     = 100

    action = {
      type             = "forward"
      target_group_arn = aws_elbv2_target_group.web_elb_target_group.arn
    }

    condition = {
      path_pattern = {
        values = ["/*"]
      }
    }
  }


resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  image_id      = data.aws_ssm_parameter.instance_ami.value
  instance_type = var.instance_type[0]
  key_name      = var.aws_key_pair[0]

  security_groups             = ["${aws_security_group.elb_sg.id}"]
  associate_public_ip_address = true
  #  user_data                   = file("install_apache.sh")

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"

  min_size         = 2
  desired_capacity = 2
  max_size         = 2

  health_check_type = "ELB"
  load_balancers = [
    "${aws_elb.web_elb.id}"
  ]

  launch_configuration = aws_launch_configuration.web.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier = [
    "${aws_subnet.servers_public_subnet.id}",
    "${aws_subnet.servers_public_subnet_02.id}"
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "webservers_01"
    propagate_at_launch = true
  }

}

resource "aws_autoscaling_policy" "web_policy_up" {
  name                   = "web_policy_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}


resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name          = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.web.name}"
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions     = ["${aws_autoscaling_policy.web_policy_up.arn}"]
}



resource "aws_autoscaling_policy" "web_policy_down" {
  name                   = "web_policy_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name          = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.web.name}"
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions     = ["${aws_autoscaling_policy.web_policy_down.arn}"]
}
