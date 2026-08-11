locals {
  common_tags = {
    env             = var.env
    managed_by      = "terraform"
    release_version = var.release_version
  }
}
