locals {
  common_tags = {
    env             = var.env
    managed_by      = "terraform"
    release_version = var.release_version
  }

  # Fluent Bit Datadog output plugin intake host, derived from the DD site.
  dd_log_intake_host = "http-intake.logs.${var.datadog_site}"
}
