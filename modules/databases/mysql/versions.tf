terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  required_providers {
    mysql = {
      source  = "petoju/mysql"
      version = "~> 3.0"
    }
  }
}
