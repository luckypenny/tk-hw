provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_vpc" "tk" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tk"
  }
}

resource "aws_internet_gateway" "tk" {
  vpc_id = "${aws_vpc.tk.id}"
  tags = {
    Name = "tk"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.tk.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.tk.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "public1" {
  vpc_id                  = "${aws_vpc.tk.id}"
  cidr_block              = "10.0.4.0/22"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "tk-pub1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = "${aws_vpc.tk.id}"
  cidr_block              = "10.0.8.0/22"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "tk-pub2"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = "${aws_subnet.public1.id}"
  route_table_id = "${aws_vpc.tk.main_route_table_id}"
}

resource "aws_route_table_association" "public2" {
  subnet_id      = "${aws_subnet.public2.id}"
  route_table_id = "${aws_vpc.tk.main_route_table_id}"
}

resource "aws_security_group" "alb" {
  name        = "tk_alb"
  description = "for tk"
  vpc_id      = "${aws_vpc.tk.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "web" {
  name               = "alb-web"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.alb.id}"]
  subnets            = ["${aws_subnet.public1.id}","${aws_subnet.public2.id}"]

  enable_deletion_protection = false

  tags = {
    Name = "tk"
  }
}

# Create WEB Target Group
resource "aws_lb_target_group" "web" {
  name     = "tk-web-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.tk.id}"
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = "${aws_lb.web.arn}"
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.web.arn}"
  }
}

# Create EIP for NAT GW
resource "aws_eip" "nat" {
  tags = {
    Name = "tk-nat"
  }
}

# Create NAT GW 
resource "aws_nat_gateway" "gw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id = "${aws_subnet.public1.id}"
  tags = {
    Name = "tk-gw"
  }
}

# Private Route Table (web, was)
resource "aws_route_table" "tk-was" {
  vpc_id = "${aws_vpc.tk.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.gw.id}"
  }

  tags = {
    Name = "tk-was"
  }
}

# Private Subnet For Web/WAS
resource "aws_subnet" "private1" {
  vpc_id                  = "${aws_vpc.tk.id}"
  cidr_block              = "10.0.16.0/20"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "tk-pri1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id                  = "${aws_vpc.tk.id}"
  cidr_block              = "10.0.32.0/20"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "tk-pri2"
  }
}

resource "aws_route_table_association" "private1" {
  subnet_id      = "${aws_subnet.private1.id}"
  route_table_id = "${aws_route_table.tk-was.id}"
}

resource "aws_route_table_association" "private2" {
  subnet_id      = "${aws_subnet.private2.id}"
  route_table_id = "${aws_route_table.tk-was.id}"
}

# Create web SSH key
resource "aws_key_pair" "web" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# Create Bastion EC2 Security Group
resource "aws_security_group" "bastion" {
  name        = "bastion_security_group"
  description = "Used in the web"
  vpc_id      = "${aws_vpc.tk.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create bastion EC2
resource "aws_instance" "bastion" {
  ami           = "ami-082bdb3b2d54d5a19"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.web.key_name}"
  security_groups = ["${aws_security_group.bastion.id}"]
  subnet_id = "${aws_subnet.public1.id}"
  associate_public_ip_address = true
  tags = {
    Name = "tk-bastion"
  }
}

# Create WEB EC2 Security Group
resource "aws_security_group" "web" {
  name        = "web_security_group"
  description = "Used in the web"
  vpc_id      = "${aws_vpc.tk.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Web LC 
resource "aws_launch_configuration" "web" {
  name          = "web_config"
  image_id      = "ami-082bdb3b2d54d5a19" #ubuntu 16.04 LTS
  instance_type = "t2.micro"
  lifecycle {
    create_before_destroy = true
  }
  key_name = "${aws_key_pair.web.key_name}"
  security_groups = ["${aws_security_group.web.id}"]

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get -y update
    sudo apt-get -y install nginx 
    sudo service nginx start
    sudo apt-get -u install git-core
  EOF
}

# Create Web AutoScaling Group
resource "aws_autoscaling_group" "web" {
  name                 = "web-asg"
  launch_configuration = "${aws_launch_configuration.web.name}"
  min_size             = 2
  max_size             = 2
  desired_capacity     = 2
  health_check_grace_period = 300
  vpc_zone_identifier = ["${aws_subnet.private1.id}","${aws_subnet.private2.id}"]
  lifecycle {
    create_before_destroy = true
  }
  target_group_arns = ["${aws_lb_target_group.web.id}"]
  health_check_type = "EC2"
  tag {
    key                 = "Name"
    value               = "tk-web"
    propagate_at_launch = true
  }
}

# Create WAS alb security group
resource "aws_security_group" "alb_internal" {
  name        = "tk_alb_internal"
  description = "for tk"
  vpc_id      = "${aws_vpc.tk.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

# Create WAS Alb (Internal)
resource "aws_lb" "was" {
  name               = "alb-was"
  internal           = true
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.alb_internal.id}"]
  subnets            = ["${aws_subnet.private1.id}","${aws_subnet.private2.id}"]

  enable_deletion_protection = false

  tags = {
    Name = "tk-internal"
  }
}

# Create WAS EC2 Security Group
resource "aws_security_group" "was" {
  name        = "was_security_group"
  description = "Used in the was"
  vpc_id      = "${aws_vpc.tk.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # HTTP access from the internal lb
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internal access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create WAS launch configuration
resource "aws_launch_configuration" "was" {
  name          = "was_config"
  image_id      = "ami-082bdb3b2d54d5a19" #ubuntu 16.04 LTS
  instance_type = "t2.micro"
  lifecycle {
    create_before_destroy = true
  }
  key_name = "${aws_key_pair.web.key_name}"
  security_groups = ["${aws_security_group.was.id}"]

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get -y update
    sudo apt-get -y install python3-pip
    sudo apt-get -y install git-core
  EOF
}

# Create WAS Target Group
resource "aws_lb_target_group" "was" {
  name     = "tk-was-lb-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.tk.id}"

  health_check {
    healthy_threshold = 2
  }
}

resource "aws_lb_listener" "was" {
  load_balancer_arn = "${aws_lb.was.arn}"
  port              = "5000"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.was.arn}"
  }
}

# Create Was AutoScaling Group
resource "aws_autoscaling_group" "was" {
  name                 = "was-asg"
  launch_configuration = "${aws_launch_configuration.was.name}"
  min_size             = 1
  max_size             = 1
  desired_capacity     = 1
  health_check_grace_period = 300
  vpc_zone_identifier = ["${aws_subnet.private1.id}","${aws_subnet.private2.id}"]
  lifecycle {
    create_before_destroy = true
  }
  target_group_arns = ["${aws_lb_target_group.was.id}"]
  health_check_type = "EC2"
  tag {
    key                 = "Name"
    value               = "was"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "rds" {
  name        = "tk_rds"
  description = "for tk rds"
  vpc_id      = "${aws_vpc.tk.id}"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

resource "aws_db_subnet_group" "tk" {
  name        = "private_subnet_group"
  description = "Our private group of subnets"
  subnet_ids  = ["${aws_subnet.private1.id}", "${aws_subnet.private2.id}"]
}

resource "aws_db_instance" "tk" {
  depends_on             = ["aws_security_group.rds"]
  identifier             = "mk-1"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  name                   = "mydb"
  username               = "user1"
  password               = "123456789"
  vpc_security_group_ids = ["${aws_security_group.rds.id}"]
  db_subnet_group_name   = "${aws_db_subnet_group.tk.id}"
  skip_final_snapshot    = true
}


