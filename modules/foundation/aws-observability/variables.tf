variable "name_prefix" {
  type = string
}

variable "logs_kms_key_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "log_group_names" {
  description = "CloudWatch log groups to create up front, e.g. for RDS exported logs."
  type        = list(string)
  default     = []
}

variable "alarm_email_endpoints" {
  type    = list(string)
  default = []
}

variable "chatops_webhook_secret_arn" {
  description = "Secrets Manager ARN holding the Slack/Teams webhook URL, subscribed via SNS->Lambda in a later phase."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
