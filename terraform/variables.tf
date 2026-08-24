variable "aws_region" {
  description = "AWS region for the Gatus infrastructure"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "gatus"
}

variable "domain_name" {
  description = "Full hostname used to access Gatus"
  type        = string
  default     = "tm.jubair-gatusmonitoringapp.co.uk"
}

variable "vpc_cidr" {
  description = "CIDR block for the Gatus VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_port" {
  description = "Port exposed by the Gatus container"
  type        = number
  default     = 8080
}

variable "container_cpu" {
  description = "CPU units for the ECS task"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memory in MB for the ECS task"
  type        = number
  default     = 512
}

variable "ecr_repository_url" {
  description = "495671351945.dkr.ecr.eu-north-1.amazonaws.com/gatus"
  type        = string
}
