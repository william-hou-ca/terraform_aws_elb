# terraform_aws_elb
aws elastic load balancer,
the main.tf covers the following topics:
  1. load balancer ( alb )
  2. load balancer listener
  3. default rule added to the listener
  4. path based rule
  5. host based rule
  6. weighted routing rule
  7. redirect
  8. fixed-response
  9. 2 target groups(default and personal)
  10. 2 launch config
  11. 2 asg
  12. 2 autoscaling_attachment
  13. an example of attaching ec2 instances to target group directly 

the nlb.tf includes:
  1. load balancer ( nlb )
  2. in accroding to the variable nlb_listeners, create its listeners
  3. create target groups for the listeners.