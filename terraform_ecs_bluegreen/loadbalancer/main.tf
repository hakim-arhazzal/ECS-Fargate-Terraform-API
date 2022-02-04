resource "aws_alb" "ecs_cluster_alb" {
  name            = "${var.ecs_cluster_name}-ALB"
  internal        = false
  security_groups = [var.alb_security_group_id]
  subnets         = var.public_subnets_id
  tags = {
    Name = "${var.ecs_cluster_name}-ALB"
  }
}

resource "aws_alb_listener" "ecs_alb_http_listener" {
  load_balancer_arn = aws_alb.ecs_cluster_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_default_target_group.arn
  }
  depends_on = [aws_alb_target_group.ecs_default_target_group]
}

resource "aws_alb_listener" "ecs_alb_test_listener" {
  load_balancer_arn = aws_alb.ecs_cluster_alb.arn
  port              = 8080
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_test_target_group.arn
  }
  depends_on = [aws_alb_target_group.ecs_test_target_group]
}

resource "aws_alb_target_group" "ecs_default_target_group" {
  name        = "ecstg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    path                = "/version"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = "10"
    timeout             = "5"
    unhealthy_threshold = "3"
    healthy_threshold   = "3"
  }
  tags = {
    Name = "${var.ecs_cluster_name}-TG"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_alb_target_group" "ecs_test_target_group" {
  name        = "ecstesttg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    path                = "/version"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = "10"
    timeout             = "5"
    unhealthy_threshold = "3"
    healthy_threshold   = "3"
  }
  tags = {
    Name = "${var.ecs_cluster_name}-TestTG"
  }
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "main" {
  name = var.dns_name
}

resource "aws_route53_record" "alias_route53_record" {
  zone_id = data.aws_route53_zone.main.zone_id # Replace with your zone ID
  name    = "fargate.${data.aws_route53_zone.main.name}" # Replace with your name/domain/subdomain
  type    = "A"

  alias {
    name                   = aws_alb.ecs_cluster_alb.dns_name
    zone_id                = aws_alb.ecs_cluster_alb.zone_id
    evaluate_target_health = true
  }
}
