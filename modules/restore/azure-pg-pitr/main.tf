# Restores to a NEW Flexible Server (spec section 13.2/13.3). Inherits the
# source's network/CMK/HA posture by virtue of create_mode PointInTimeRestore
# copying most configuration from the source automatically; anything this
# resource doesn't carry over explicitly is a gap to close before relying on
# this for a real drill (see docs/runbooks/restore-postgres.md).
# TODO(verify): confirm azurerm ~> 4.0's exact argument set for a
# PointInTimeRestore azurerm_postgresql_flexible_server — in particular
# whether delegated_subnet_id/private_dns_zone_id are required again here
# or inherited from source_server_id.
resource "azurerm_postgresql_flexible_server" "restored" {
  name                = "${basename(var.source_server_id)}-r${var.restore_tag}"
  resource_group_name = var.resource_group_name
  location             = var.location

  create_mode                     = "PointInTimeRestore"
  source_server_id                = var.source_server_id
  point_in_time_restore_time_in_utc = var.restore_time_utc

  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = var.private_dns_zone_id

  tags = merge(var.tags, {
    purpose          = "restore"
    "restore-ticket" = var.ticket
    "requested-by"   = var.requested_by
    ttl              = var.ttl_at_utc
  })

  lifecycle {
    ignore_changes = [zone]
  }
}
