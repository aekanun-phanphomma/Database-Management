terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  required_providers {
    mssql = {
      source  = "PGSSoft/mssql"
      version = "~> 0.6"
    }
  }
}
