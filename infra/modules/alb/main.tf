resource "aws_lb" "gatus" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    var.alb_security_group_id
  ]


  subnets = var.public_subnet_ids


  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "gatus" {
  name        = "${var.project_name}-targets"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"

  vpc_id = var.vpc_id


  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-targets"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.gatus.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.gatus.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"

  certificate_arn = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gatus.arn
  }
}
