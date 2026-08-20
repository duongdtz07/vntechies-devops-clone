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
  default = 1024
}

variable "frontend_memory" {
  type    = number
  default = 2048
}

variable "backend_cpu" {
  type    = number
  default = 512
}

variable "backend_memory" {
  type    = number
  default = 1024
}

variable "datadog_api_key" {
  type        = string
  sensitive   = true
  description = "Datadog API key. Set via TF_VAR_datadog_api_key or a secrets-backed tfvars. Never commit the value."
}

variable "datadog_site" {
  type        = string
  default     = "datadoghq.com"
  description = "Datadog intake site (e.g. datadoghq.com, datadoghq.eu, us3.datadoghq.com, ap1.datadoghq.com)."
}

variable "frontend_desired_count" {
  type    = number
  default = 1
}

variable "backend_desired_count" {
  type    = number
  default = 1
}
