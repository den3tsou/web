output "alb_hostname" {
  value = "${aws_alb.public_load_balancer.dns_name}"
}
