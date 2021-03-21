output "nlb_name" {
  value = aws_lb.nlb[0].dns_name
}
