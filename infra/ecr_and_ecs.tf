resource "aws_ecr_repository" "web" {
  name                 = "web/web"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

data "aws_ecr_lifecycle_policy_document" "web" {
  rule {
    priority    = 1
    description = "the web server image"
    selection {
      tag_status   = "any"
      count_type   = "imageCountMoreThan"
      count_number = 1
    }
  }
}

resource "aws_ecr_lifecycle_policy" "web" {
  repository = aws_ecr_repository.web.name

  policy = data.aws_ecr_lifecycle_policy_document.web.json
}

resource "aws_security_group" "public_load_balancer" {
  name        = "public-load-balancer"
  description = "controls access to the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_services" {
  name        = "ecs-services"
  description = "allow inbound access from the ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8080
    security_groups = [aws_security_group.public_load_balancer.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "public_load_balancer" {
  name            = "load-balancer"
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.public_load_balancer.id]
}

resource "aws_alb_target_group" "web" {
  name = "web"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/healthcheck"
    unhealthy_threshold = "2"
  }
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.public_load_balancer.id
  port     = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.web.id
    type             = "forward"
  }
}

resource "aws_ecs_cluster" "web" {
  name = "web"
}

resource "aws_ecs_cluster_capacity_providers" "web" {
  cluster_name       = aws_ecs_cluster.web.name
  capacity_providers = ["FARGATE_SPOT"]
}

# Use the default AWS role for now
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

resource "aws_cloudwatch_log_group" "ecs_web" {
  name              = "/ecs/web"
  retention_in_days = 1

  tags = {
    Name = "ecs-web"
  }
}

# TODO: add autoscaling
resource "aws_ecs_task_definition" "web" {
  family                   = "web"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name   = "web"
      image  = "${aws_ecr_repository.web.repository_url}:1"
      cpu    = 256
      memory = 512
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/web"
          awslogs-region        = "ap-southeast-2"
          awslogs-stream-prefix = "ecs"
        }
      }
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "web" {
  name            = "web"
  cluster         = aws_ecs_cluster.web.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    security_groups  = [aws_security_group.ecs_services.id]

    # FIXME: this is a temporary solution to allow ECS task to pull image from ECR
    # ECS platform 1.4.0 uses the same Elastic Network Interface as the subnet. This
    # means that the workaround is either
    # 1) Make the task have public IP, so this task is able to pull image from ECR (the current approach)
    # 2) Make this part of the private subtnet and add a NAT in the subnet, so the task
    # is able to pull the image from ECR
    subnets          = aws_subnet.public.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.web.id
    container_name   = "web"
    container_port   = 8080
  }

  depends_on = [aws_alb_listener.front_end]
}

