variable "env" {
  type    = string
  default = "dev"
}

variable "release_version" {
  type        = string
  default     = "untagged"
  description = "Git release tag applied to all resources (e.g. v1.2.3). Set automatically by CI; defaults to 'untagged' for local runs."
}

variable "frontend_image_tag" {
  type        = string
  default     = "latest"
  description = "Docker image tag to deploy for the frontend service."
}

variable "backend_image_tag" {
  type        = string
  default     = "latest"
  description = "Docker image tag to deploy for the backend service."
}

variable "frontend_cpu" {
  type    = number
  default = 512
}

variable "frontend_memory" {
  type    = number
  default = 1024
}

variable "backend_cpu" {
  type    = number
  default = 256
}

variable "backend_memory" {
  type    = number
  default = 512
}

variable "frontend_desired_count" {
  type    = number
  default = 1
}

variable "backend_desired_count" {
  type    = number
  default = 1
}
