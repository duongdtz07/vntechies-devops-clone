variable "env" {
  type    = string
  default = "dev"
}

variable "release_version" {
  type        = string
  default     = "untagged"
  description = "Git release tag. Set automatically by CI."
}

variable "k8s_version" {
  type        = string
  default     = "1.30"
  description = "EKS Kubernetes version."
}

variable "node_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type for the managed node group."
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 4
}
