variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "runner_image" {
  description = "ECR image URI for the self-hosted actions runner."
  type        = string
}

variable "task_cpu" {
  type    = number
  default = 1024
}

variable "task_memory" {
  type    = number
  default = 2048
}

variable "l_layer_role_arns" {
  description = "Map layer (l0..l3) => IAM role ARN the runner assumes for that layer's Terraform operations."
  type        = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
