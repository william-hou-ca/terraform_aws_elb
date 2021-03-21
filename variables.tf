variable "load_balancer_type" {
  type        = string
  default     = "alb"
  description = "this is invalid"

  validation {
    condition     = var.load_balancer_type == "alb" || var.load_balancer_type == "nlb"
    error_message = "Load balancer type should be alb or nlb."
  }
}

variable "tg_name" {
  type    = list(string)
  default = ["default", "personal"]
}

#################################variables for nlb###############################
variable "create_nlb" {
  type = bool
  default = true
}

variable "nlb_listeners" {
  type = list(object({
    protocol = string
    port = number
    target_group_index = number
    })
  )

  default = [
    {
      protocol = "TCP"
      port = 80
      target_group_index = 2
    },
    {
      protocol = "UDP"
      port = 81
      target_group_index = 1
    },
    {
      protocol = "TCP_UDP"
      port = 82
      target_group_index = 0
    }
  ]
}

variable "nlb_target_groups" {
  type = list(object({
    name_prefix = string
    backend_protocol = string
    backend_port = number
    target_type = string
    }))
  default = [
    {
      name_prefix      = "tu1-"
      backend_protocol = "TCP_UDP"
      backend_port     = 81
      target_type      = "instance"
    },
    {
      name_prefix      = "u1-"
      backend_protocol = "UDP"
      backend_port     = 82
      target_type      = "instance"
    },
    {
      name_prefix = "t1-"
      backend_protocol = "TCP"
      backend_port = 80
      target_type = "instance"
    }
  ]
}
