provider "aws" {
  region =  "ca-central-1"
}

###########################################################################
#
# Create an Application Load Balancer or Network Load Balancer
#
###########################################################################

resource "aws_lb" "lb" {
  name        = "terraform-lb-${var.load_balancer_type}"
  internal           = false
  load_balancer_type = var.load_balancer_type == "alb" ? "application" : "network"

  # Only valid for Load Balancers of type application
  security_groups    = var.load_balancer_type == "alb" ? data.aws_security_groups.default_sg.ids : []
  
  subnets            = data.aws_subnet_ids.default_subnets.ids

  enable_deletion_protection = false

/*
  access_logs {
    bucket  = aws_s3_bucket.lb_logs.bucket
    prefix  = "test-lb"
    enabled = true
  }
*/

  tags = {
    Type = var.load_balancer_type
  }
}

###########################################################################
#
# Create a Load Balancer Listener
#
###########################################################################

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg[0].arn
  }
}

###########################################################################
#
# Create Load Balancer Listener rules 
#
###########################################################################

# Static forward
resource "aws_lb_listener_rule" "lbr_static" {
  listener_arn = aws_lb_listener.lb_listener.arn
  
  # Leaving it unset will automatically set the rule with next available priority after currently existing highest rule. 
  # A listener can't have multiple rules with the same priority.
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg[1].arn
  }

  condition {
    path_pattern {
      values = ["/static/*"]
    }
  }
}

# Host based forward
resource "aws_lb_listener_rule" "host_based_routing" {
  listener_arn = aws_lb_listener.lb_listener.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg[1].arn
  }

  condition {
    /*
    host_header {
      values = ["terraform-lb-alb-*.ca-central-1.elb.amazonaws.com"]
    }
    */
    query_string {
      key   = "type"
      value = "hbr"
    }
  }
}

# Weighted Forward action
resource "aws_lb_listener_rule" "weihted_routing" {
  listener_arn = aws_lb_listener.lb_listener.arn
  priority     = 30

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.lb_tg[0].arn
        weight = 50
      }

      target_group {
        arn    = aws_lb_target_group.lb_tg[1].arn
        weight = 50
      }

      /*
      stickiness {
        enabled  = true
        duration = 600
      }
      */
    }
  }

  condition {
    query_string {
      key   = "type"
      value = "wr"
    }
  }
}

# Redirect action
resource "aws_lb_listener_rule" "redirect_http_to_https" {
  listener_arn = aws_lb_listener.lb_listener.arn

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
      host = "www.google.ca"
      path = "/"
    }
  }

  condition {
    query_string {
      key   = "type"
      value = "rhth"
    }
  }
}

# Fixed-response action
resource "aws_lb_listener_rule" "health_check" {
  listener_arn = aws_lb_listener.lb_listener.arn

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "HEALTHY-${var.load_balancer_type}"
      status_code  = "200"
    }
  }

  condition {
    query_string {
      key   = "type"
      value = "hc"
    }
  }
}

###########################################################################
#
# Create Target Group resource for load balancer listener
#
###########################################################################

resource "aws_lb_target_group" "lb_tg" {
  count = length(var.tg_name)

  name     = "tf-lb-tg-${var.tg_name[count.index]}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_vpc.id

}

###########################################################################
#
# Create ec2 instance and autoscaling group resource for Target group
#
###########################################################################

resource "aws_launch_configuration" "lc" {
  count = length(var.tg_name)

  name          = "terraform-lc-${var.tg_name[count.index]}"
  image_id      = data.aws_ami.amz2.id
  instance_type = "t2.micro"

  user_data = <<-EOF
            #! /bin/sh
            sudo yum update -y
            sudo amazon-linux-extras install -y nginx1
            sudo systemctl start nginx
            sudo curl -s http://169.254.169.254/latest/meta-data/local-hostname >/tmp/hostname.html
            sudo echo -e "\n<h1>asg: ${var.tg_name[count.index]}</>" >>/tmp/hostname.html
            sudo mv /tmp/hostname.html /usr/share/nginx/html/index.html
            sudo chmod a+r /usr/share/nginx/html/index.html
            sudo mkdir /usr/share/nginx/html/static/
            sudo chmod a+r /usr/share/nginx/html/static/
            sudo cp /usr/share/nginx/html/index.html /usr/share/nginx/html/static/.
            EOF

  lifecycle {
    create_before_destroy = true
  }

  associate_public_ip_address = true
  security_groups = data.aws_security_groups.default_sg.ids
  key_name = "key-hr123000" #key paire name exists in my aws.You should use your owned key nam

}

resource "aws_autoscaling_group" "asg" {
  count = length(var.tg_name)
  name                 = "terraform-asg-${var.tg_name[count.index]}"
  launch_configuration = aws_launch_configuration.lc[count.index].name
  min_size             = 1
  max_size             = 2

  health_check_grace_period = 300
  availability_zones = data.aws_availability_zones.available_zones.names

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup = 30
    }
  }

  tag {
    key                 = "asg"
    value               = var.tg_name[count.index]
    # when propagate is true, this tag will be attached to instances.
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

###########################################################################
#
# Attach asg to tg
#
###########################################################################

resource "aws_autoscaling_attachment" "asg_attachment" {
  count = length(var.tg_name)
  autoscaling_group_name = aws_autoscaling_group.asg[count.index].id
  alb_target_group_arn   = aws_lb_target_group.lb_tg[count.index].arn
}

###########################################################################
#
# Attach an instance to target group 'default'
# you could directly register ec2 instance to target group
#
###########################################################################
/*
resource "aws_instance" "ec2" {
  
  ami      = data.aws_ami.amz2.id
  instance_type = "t2.micro"

  user_data = <<-EOF
            #! /bin/sh
            sudo yum update -y
            sudo amazon-linux-extras install -y nginx1
            sudo systemctl start nginx
            sudo curl -s http://169.254.169.254/latest/meta-data/local-hostname >/tmp/hostname.html
            sudo echo "ec2: instance" >>/tmp/hostname.html
            sudo mv /tmp/hostname.html /usr/share/nginx/html/index.html
            sudo chmod a+r /usr/share/nginx/html/index.html
            sudo mkdir /usr/share/nginx/html/static/
            sudo chmod a+r /usr/share/nginx/html/static/
            sudo cp /usr/share/nginx/html/index.html /usr/share/nginx/html/static/.
            EOF

  lifecycle {
    create_before_destroy = true
  }

  associate_public_ip_address = true
  vpc_security_group_ids = data.aws_security_groups.default_sg.ids
  key_name = "key-hr123000" #key paire name exists in my aws.You should use your owned key nam

  tags = {
    Name = "terraform-lb-tg-ec2"
  }
}

resource "aws_lb_target_group_attachment" "lb_tg_ins_attchement" {
  target_group_arn = aws_lb_target_group.lb_tg[0].arn
  target_id        = aws_instance.ec2.id
  port             = 80
}
*/