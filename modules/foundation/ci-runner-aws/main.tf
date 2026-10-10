# Ephemeral, VPC-resident GitHub Actions runner on Fargate. No static AWS
# keys: the runner authenticates to GitHub via a short-lived registration
# token fetched at container start (TODO(verify): wire to the GitHub App /
# PAT rotation mechanism chosen at implementation time — out of scope for
# this module, which only owns the compute and network path), and assumes
# the per-layer IAM role (l_layer_role_arns) via its task role for each
# Terraform operation, scoped to one layer at a time by the pipeline step.

data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-runner-exec"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-runner-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "task_assume_layers" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = values(var.l_layer_role_arns)
  }
}

resource "aws_iam_role_policy" "task_assume_layers" {
  name   = "${var.name_prefix}-runner-assume-layers"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_assume_layers.json
}

resource "aws_security_group" "runner" {
  name_prefix = "${var.name_prefix}-runner-"
  description = "Egress-only; no ingress. Runner initiates all connections."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-runners"
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "runner" {
  name              = "/ecs/${var.name_prefix}-runner"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_ecs_task_definition" "runner" {
  family                   = "${var.name_prefix}-runner"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name  = "runner"
    image = var.runner_image
    environment = [
      { name = "GITHUB_ORG", value = var.github_org },
      { name = "GITHUB_REPO", value = var.github_repo },
      { name = "EPHEMERAL", value = "true" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.runner.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "runner"
      }
    }
  }])

  tags = var.tags
}
