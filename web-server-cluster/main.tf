provider "aws" { 
  region = "us-east-2"
}

resource "aws_launch_configuration" "example" {
  image_id = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  security_groups = [ aws_security_group.instance.id ]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  # Required when using a launch configuration with an auto scaling group. 
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html 
  lifecycle {
    create_before_destroy = true 
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  // This parameter specifies to the ASG into which VPC subnets the EC2 Instances should be deployed
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  // This let the target group know which EC2 Instances to send requests to.
  target_group_arns = [aws_lb_target_group.asg.arn]
  // It instructs the ASG to use the target group’s health check to determine whether an Instance is healthy 
  // and to automatically replace Instances if the target group reports them as unhealthy. 
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_lb" "example" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.default.ids
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port = 80
  protocol = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    } 
  }
}

resource "aws_lb_target_group" "asg" {
  name = "terraform-asg-example" 
  port = var.server_port
  protocol = "HTTP"
  vpc_id =data.aws_vpc.default.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

// The code adds a listener rule that send requests that match any path to the target group that contains your ASG.
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

// By default, AWS does not allow any incoming or outgoing traffic from an EC2 Instance.
// To Allow the EC2 to receive traffic on 8080, It requires you to create a security group.
resource "aws_security_group" "instance" { 
  name = "terraform-example-instance"
  
  ingress {
    from_port = var.server_port
    to_port = var.server_port 
    protocol = "tcp" 
    // The CIDR block 0.0.0.0/0 is an IP address range that includes all possible IP addresses.
    // so this security group allows incoming requests on port 8080 from any IP.7
    cidr_blocks = ["0.0.0.0/0"]
  } 
}

resource "aws_security_group" "alb" { 
  name = "terraform-example-alb"
  
  # Allow inbound HTTP requests
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp" 
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1" 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type = number
  default = 8080
}

data "aws_vpc" "default" {
   default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}