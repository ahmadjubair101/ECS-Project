moved {
  from = aws_vpc.main
  to   = module.networking.aws_vpc.main
}

moved {
  from = aws_subnet.public_a
  to   = module.networking.aws_subnet.public_a
}

moved {
  from = aws_subnet.public_b
  to   = module.networking.aws_subnet.public_b
}

moved {
  from = aws_subnet.private_a
  to   = module.networking.aws_subnet.private_a
}

moved {
  from = aws_subnet.private_b
  to   = module.networking.aws_subnet.private_b
}

moved {
  from = aws_internet_gateway.main
  to   = module.networking.aws_internet_gateway.main
}

moved {
  from = aws_route_table.public
  to   = module.networking.aws_route_table.public
}

moved {
  from = aws_route_table_association.public_a
  to   = module.networking.aws_route_table_association.public_a
}

moved {
  from = aws_route_table_association.public_b
  to   = module.networking.aws_route_table_association.public_b
}

moved {
  from = aws_eip.nat
  to   = module.networking.aws_eip.nat
}

moved {
  from = aws_nat_gateway.main
  to   = module.networking.aws_nat_gateway.main
}

moved {
  from = aws_route_table.private
  to   = module.networking.aws_route_table.private
}

moved {
  from = aws_route_table_association.private_a
  to   = module.networking.aws_route_table_association.private_a
}

moved {
  from = aws_route_table_association.private_b
  to   = module.networking.aws_route_table_association.private_b
}

moved {
  from = aws_security_group.alb
  to   = module.security.aws_security_group.alb
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_http
  to   = module.security.aws_vpc_security_group_ingress_rule.alb_http
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_https
  to   = module.security.aws_vpc_security_group_ingress_rule.alb_https
}

moved {
  from = aws_vpc_security_group_egress_rule.alb_all
  to   = module.security.aws_vpc_security_group_egress_rule.alb_all
}

moved {
  from = aws_security_group.ecs
  to   = module.security.aws_security_group.ecs
}

moved {
  from = aws_vpc_security_group_ingress_rule.ecs_from_alb
  to   = module.security.aws_vpc_security_group_ingress_rule.ecs_from_alb
}

moved {
  from = aws_vpc_security_group_egress_rule.ecs_all
  to   = module.security.aws_vpc_security_group_egress_rule.ecs_all
}

moved {
  from = aws_iam_role.ecs_task_execution
  to   = module.iam.aws_iam_role.ecs_task_execution
}

moved {
  from = aws_iam_role_policy_attachment.ecs_task_execution
  to   = module.iam.aws_iam_role_policy_attachment.ecs_task_execution
}

moved {
  from = aws_cloudwatch_log_group.gatus
  to   = module.monitoring.aws_cloudwatch_log_group.gatus
}

moved {
  from = aws_acm_certificate.gatus
  to   = module.certificate.aws_acm_certificate.gatus
}

moved {
  from = aws_route53_record.acm_validation
  to   = module.certificate.aws_route53_record.acm_validation
}

moved {
  from = aws_acm_certificate_validation.gatus
  to   = module.certificate.aws_acm_certificate_validation.gatus
}

moved {
  from = aws_lb.gatus
  to   = module.alb.aws_lb.gatus
}

moved {
  from = aws_lb_target_group.gatus
  to   = module.alb.aws_lb_target_group.gatus
}

moved {
  from = aws_lb_listener.http
  to   = module.alb.aws_lb_listener.http
}

moved {
  from = aws_lb_listener.https
  to   = module.alb.aws_lb_listener.https
}

moved {
  from = aws_route53_record.gatus
  to   = module.dns.aws_route53_record.gatus
}

moved {
  from = aws_ecs_cluster.main
  to   = module.ecs.aws_ecs_cluster.main
}

moved {
  from = aws_ecs_task_definition.gatus
  to   = module.ecs.aws_ecs_task_definition.gatus
}

moved {
  from = aws_ecs_service.gatus
  to   = module.ecs.aws_ecs_service.gatus
}

moved {
  from = aws_iam_openid_connect_provider.github
  to   = module.github_oidc.aws_iam_openid_connect_provider.github
}

moved {
  from = aws_iam_role.github_actions
  to   = module.github_oidc.aws_iam_role.github_actions
}

moved {
  from = aws_iam_role_policy_attachment.github_actions_ecr
  to   = module.github_oidc.aws_iam_role_policy_attachment.github_actions_ecr
}

moved {
  from = aws_iam_role_policy_attachment.github_actions_ecs
  to   = module.github_oidc.aws_iam_role_policy_attachment.github_actions_ecs
}
