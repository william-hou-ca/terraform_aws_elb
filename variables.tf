variable "load_balancer_type" {
  type = string
  default = "alb"
  description = "choose to create alb or nlb"

  validation {
    condition = var.load_balancer_type == "alb" || var.load_balancer_type == "nlb"
    error_message = "Load balancer type should be alb or nlb."
  }
}

variable "tg_name" {
  type = list(string)
  default = ["default", "personal"]
}