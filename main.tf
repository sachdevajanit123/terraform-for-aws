provider "aws" {
  profile ="default"
  region = "us-east-1"
}

resource "aws_vpc" "demo-vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public-subnet" {
  vpc_id = "${aws_vpc.demo-vpc.id}"
  cidr_block = "10.0.1.0/24"
  tags = {
      Name = "public-subnet"
  }
  availability_zone = "us-east-1a"
}

  resource "aws_subnet" "public-subnet2" {
  vpc_id = "${aws_vpc.demo-vpc.id}"
  cidr_block = "10.0.2.0/24"
  tags = {
      Name = "public-subnet2"
  }
  availability_zone = "us-east-1b"
  }

resource "aws_internet_gateway" "vpc-igw" {
  vpc_id = "${aws_vpc.demo-vpc.id}"
}

resource "aws_route_table" "demo-rtb" {
   vpc_id = "${aws_vpc.demo-vpc.id}"

   route {
     cidr_block = "0.0.0.0/0"
     gateway_id = "${aws_internet_gateway.vpc-igw.id}"
   }
}

resource "aws_route_table_association" "demo-rtb-association1" {
  route_table_id = "${aws_route_table.demo-rtb.id}"
  subnet_id = "${aws_subnet.public-subnet.id}"
}

resource "aws_route_table_association" "demo-rtb-association2" {
  route_table_id = "${aws_route_table.demo-rtb.id}"
  subnet_id = "${aws_subnet.public-subnet2.id}"
}


resource "aws_network_acl" "public-nacl" {
  vpc_id = "${aws_vpc.demo-vpc.id}"
  subnet_ids = ["${aws_subnet.public-subnet.id}", "${aws_subnet.public-subnet2.id}" ]

  ingress{
      rule_no = "100"
      protocol = "tcp"
      from_port = "80"
      to_port = "80"
      action = "allow"
      cidr_block = "0.0.0.0/0"
  }
  ingress{
      rule_no = "200"
      protocol = "tcp"
      from_port = "1025"
      to_port = "65535"
      action = "allow"
      cidr_block = "0.0.0.0/0"
  }
  ingress{
      rule_no = "300"
      protocol = "tcp"
      from_port = "22"
      to_port = "22"
      action = "allow"
      cidr_block = "0.0.0.0/0"
  }

  egress{
      rule_no = "100"
      protocol = "tcp"
      from_port = "80"
      to_port = "80"
      action = "allow"
      cidr_block = "0.0.0.0/0"
  }

  egress{
      rule_no = "200"
      protocol = "tcp"
      from_port = "1025"
      to_port = "65535"
      action = "allow"
      cidr_block = "0.0.0.0/0"
  }
   egress{
      rule_no = "300"
      protocol = "tcp"
      from_port = "22"
      to_port = "22"
      action = "allow"
      cidr_block = "0.0.0.0/0"
  }
  
}

resource "aws_security_group" "webserver-sg" {
  name = "WebDMZ"
  description = "Security group for web server"
  vpc_id = "${aws_vpc.demo-vpc.id}"

ingress{
      from_port = "80"
      to_port = "80"
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress{
      from_port = "22"
      to_port = "22"
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

}
resource "aws_security_group" "lb-sg" {
name = "LoadBalancerSG"
description = "Security group for load balancer"
vpc_id = "${aws_vpc.demo-vpc.id}"


ingress{
      from_port = "80"
      to_port = "80"
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

 egress{
      from_port = "80"
      to_port = "80"
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "db-sg" {
name = "MysqlSG"
description = "Security group for My Sql"
vpc_id = "${aws_vpc.demo-vpc.id}"


ingress{
      from_port = "3306"
      to_port = "3306"
      protocol = "tcp"
       cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web-server1" {
  ami = "ami-0fc61db8544a617ed"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.webserver-sg.id}" ]
  key_name = "DemoKeyPair"
  user_data = "${file("script.sh")}"
}

resource "aws_instance" "web-server2"{
  ami = "ami-0fc61db8544a617ed"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public-subnet2.id}"
  vpc_security_group_ids = ["${aws_security_group.webserver-sg.id}" ]
  key_name = "DemoKeyPair"
  user_data = "${file("script2.sh")}"

}

resource "aws_lb" "web-lb" {
  name = "web-lb"
  load_balancer_type = "application"
  internal = false
  subnets = ["${aws_subnet.public-subnet.id}", "${aws_subnet.public-subnet2.id}"]
  security_groups = ["${aws_security_group.lb-sg.id}"]
}

resource "aws_lb_listener" "web-lb-listener" {
  load_balancer_arn = "${aws_lb.web-lb.arn}"
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = "${aws_lb_target_group.web-tg.arn}"
  }

}

resource "aws_lb_target_group" "web-tg" {
  name = "web-tg"
  port = "80"
  protocol = "HTTP"
  vpc_id = "${aws_vpc.demo-vpc.id}"
}

resource "aws_lb_target_group_attachment" "web-tg-attach1" {
  target_group_arn = "${aws_lb_target_group.web-tg.arn}"
  target_id = "${aws_instance.web-server1.id}"
  port  = "80"
}
resource "aws_lb_target_group_attachment" "web-tg-attach2" {
  target_group_arn = "${aws_lb_target_group.web-tg.arn}"
  target_id = "${aws_instance.web-server2.id}"
  port  = "80"
}

resource "aws_db_subnet_group" "mysql-subnet-group" {
  name = "mysql-subnet-group"
  subnet_ids = [ "${aws_subnet.public-subnet.id}", "${aws_subnet.public-subnet2.id}"]
}


resource "aws_db_instance" "mysqldb" {
  allocated_storage = "20"
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "5.7.22"
  instance_class = "db.t2.micro"
  name = "mysqldb"
  username = "mysql_user"
  password = "mysql-password"
  skip_final_snapshot = "true"
  db_subnet_group_name = "${aws_db_subnet_group.mysql-subnet-group.id}"
  vpc_security_group_ids = ["${aws_security_group.db-sg.id}"]
  
}