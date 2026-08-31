output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = aws_iam_role.ecs_task_execution.arn
}
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group used by Gatus"
  value       = aws_cloudwatch_log_group.gatus.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the Gatus ECS task definition"
  value       = aws_ecs_task_definition.gatus.arn
}

output "alb_dns_name" {
  description = "DNS name of the Gatus Application Load Balancer"
  value       = aws_lb.gatus.dns_name
}

output "alb_arn" {
  description = "ARN of the Gatus Application Load Balancer"
  value       = aws_lb.gatus.arn
}

output "target_group_arn" {
  description = "ARN of the Gatus target group"
  value       = aws_lb_target_group.gatus.arn
}

output "acm_certificate_arn" {
  description = "ARN of the Gatus ACM certificate"
  value       = aws_acm_certificate.gatus.arn
}

output "ecs_service_name" {
  description = "Name of the Gatus ECS service"
  value       = aws_ecs_service.gatus.name
}

output "gatus_url" {
  description = "URL for the Gatus monitoring dashboard"
  value       = "https://${var.domain_name}"
}

output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions through OIDC"
  value       = aws_iam_role.github_actions.arn
}
