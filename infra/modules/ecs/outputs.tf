output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.gatus.arn
}

output "service_name" {
  value = aws_ecs_service.gatus.name
}

output "service_id" {
  value = aws_ecs_service.gatus.id
}
