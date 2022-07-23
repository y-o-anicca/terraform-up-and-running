module "asg" {
  source = "../../cluster/asg-rolling-deploy"
  cluster_name  = "hello-world-${var.environment}"
  ami           = var.ami
  user_data     = data.template_file.user_data.rendered
  instance_type = var.instance_type
  min_size           = var.min_size
  max_size           = var.max_size
  enable_autoscaling = var.enable_autoscaling
  subnet_ids = data.aws_subnet_ids.default.ids 
  target_group_arns = [aws_lb_target_group.asg.arn] 
  health_check_type = "ELB"
  custom_tags = var.custom_tags
}

module "alb" {
  source = "../../networking/alb"
  alb_name ="hello-world-${var.environment}"
  subnet_ids = data.aws_subnet_ids.default.ids 
}

resource "aws_lb_target_group" "asg" {
  name = "hello-world-${var.environment}"
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
  listener_arn = module.alb.alb_http_listener_arn
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

data "aws_vpc" "default" {
   default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-2"
  }
}