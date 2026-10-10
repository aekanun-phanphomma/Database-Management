output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.runner.arn
}

output "security_group_id" {
  value = aws_security_group.runner.id
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
