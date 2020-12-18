output "alb_hostname" {
  value = "${aws_alb.jalcalaroot.dns_name}"
}
