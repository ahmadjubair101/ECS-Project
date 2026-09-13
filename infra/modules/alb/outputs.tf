output "alb_arn" {
  value = aws_lb.gatus.arn
}

output "alb_dns_name" {
  value = aws_lb.gatus.dns_name
}

output "alb_zone_id" {
  value = aws_lb.gatus.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.gatus.arn
}

output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}
