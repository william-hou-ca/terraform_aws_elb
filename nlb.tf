provider "aws" {
  region =  "ca-central-1"
}

resource "aws_lb" "nlb" {
  count = var.create_nlb ? 1 : 0

  name = "tf-nlb"
  load_balancer_type = "network"
  internal = false
  subnets = data.aws_subnet_ids.default_subnets.ids
  enable_deletion_protection = false

  tags = {
    Type = "nlb"
  }
}

resource "aws_lb_listener" "nlb" {
  count = var.create_nlb ? length(var.nlb_listeners) : 0

  load_balancer_arn = aws_lb.nlb[0].arn

  protocol = var.nlb_listeners[count.index].protocol
  port = var.nlb_listeners[count.index].port

  dynamic "default_action" {
    for_each = length(keys(var.nlb_listeners[count.index])) == 0 ? [] : [var.nlb_listeners[count.index]]

    content {
      type = "forward" #nlb just supports forward type
      target_group_arn = aws_lb_target_group.main[lookup(default_action.value, "target_group_index", count.index)].id
    }
  }
}
 
resource "aws_lb_target_group" "main" {
  count = var.create_nlb ? length(var.nlb_target_groups) : 0

  name_prefix = var.nlb_target_groups[count.index].name_prefix
  port = var.nlb_target_groups[count.index].backend_port
  protocol = var.nlb_target_groups[count.index].backend_protocol
  vpc_id   = data.aws_vpc.default_vpc.id
}