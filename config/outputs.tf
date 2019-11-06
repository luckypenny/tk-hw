output "dns_was_lb" {
  description = "The DNS name of the WAS ELB"
  value = "${aws_lb.was.dns_name}"
}

output "dns_web_lb" {
  value = "${aws_lb.web.dns_name}"
}

output "bastion_public_ip" {
  value = "${aws_instance.bastion.public_ip}"
}

output "rds_endpoint" {
  value = "${aws_db_instance.tk.endpoint}"
}