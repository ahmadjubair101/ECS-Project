variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "container_port" {
  type = number
}

variable "container_cpu" {
  type = number
}

variable "container_memory" {
  type = number
}

variable "ecr_repository_url" {
  type = string
}

variable "ecs_task_execution_role_arn" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}
