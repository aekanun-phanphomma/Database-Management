resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(var.log_group_names)

  name              = each.key
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logs_kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic" "alarms" {
  name              = "${var.name_prefix}-db-alarms"
  kms_master_key_id = var.logs_kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.alarm_email_endpoints)
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.key
}

# DB event subscriptions (RDS). Source IDs are attached per-server at L1
# via aws_db_event_subscription with this topic — this just owns the topic.
