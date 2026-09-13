output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = module.iam.ecs_task_execution_role_arn
}
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group used by Gatus"
  value       = module.monitoring.log_group_name
}

output "ecs_task_definition_arn" {
  description = "ARN of the Gatus ECS task definition"
  value       = module.ecs.task_definition_arn
}

output "alb_dns_name" {
  description = "DNS name of the Gatus Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Gatus Application Load Balancer"
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "ARN of the Gatus target group"
  value       = module.alb.target_group_arn
}

output "acm_certificate_arn" {
  description = "ARN of the Gatus ACM certificate"
  value       = module.certificate.certificate_arn
}

output "ecs_service_name" {
  description = "Name of the Gatus ECS service"
  value       = module.ecs.service_name
}

output "gatus_url" {
  description = "URL for the Gatus monitoring dashboard"
  value       = "https://${var.domain_name}"
}

output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions through OIDC"
  value       = module.github_oidc.github_actions_role_arn
}
