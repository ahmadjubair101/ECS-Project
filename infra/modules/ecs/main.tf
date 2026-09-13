resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

resource "aws_ecs_task_definition" "gatus" {
  family                   = var.project_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = tostring(var.container_cpu)
  memory = tostring(var.container_memory)

  execution_role_arn = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = var.project_name
      image     = var.ecr_repository_url
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "wget -q -O - http://localhost:8080/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "gatus"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-task-definition"
  }
}

resource "aws_ecs_service" "gatus" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.gatus.arn

  desired_count = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets = var.private_subnet_ids


    security_groups = [
      var.ecs_security_group_id
    ]


    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.project_name
    container_port   = var.container_port
  }



  tags = {
    Name = "${var.project_name}-service"
  }
}
