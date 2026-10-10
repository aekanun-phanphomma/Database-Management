# Single source of truth for backup/DR tiering (spec section 13.1).
# Every L1 server module and every restore module reads this instead
# of hard-coding retention numbers, so changing a tier's policy never
# requires touching more than one file.

output "policy" {
  description = "Backup/DR policy keyed by tier name."
  value = {
    tier1 = {
      rpo_minutes            = 5
      rto_minutes            = 60
      pitr_retention_days    = 35
      long_term_monthly      = 12
      long_term_yearly       = 7
      cross_region           = true
      cross_account_locked   = true
      geo_redundant          = true
      drill_frequency        = "monthly"
    }
    tier2 = {
      rpo_minutes            = 15
      rto_minutes            = 240
      pitr_retention_days    = 14
      long_term_monthly      = 6
      long_term_yearly       = 0
      cross_region           = true
      cross_account_locked   = true
      geo_redundant          = true
      drill_frequency        = "quarterly"
    }
    tier3 = {
      rpo_minutes            = 1440
      rto_minutes            = 1440
      pitr_retention_days    = 7
      long_term_monthly      = 0
      long_term_yearly       = 0
      cross_region           = false
      cross_account_locked   = false
      geo_redundant          = false
      drill_frequency        = "semi-annual"
    }
  }
}
