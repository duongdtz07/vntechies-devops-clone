variable "env" {
  type    = string
  default = "dev"
}

variable "release_version" {
  type        = string
  default     = "untagged"
  description = "Git release tag applied to all resources. Set automatically by CI."
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for the Auto Scaling Group."
}

variable "min_size" {
  type        = number
  default     = 1
  description = "Minimum number of EC2 instances in the ASG."
}

variable "max_size" {
  type        = number
  default     = 3
  description = "Maximum number of EC2 instances in the ASG."
}

variable "desired_capacity" {
  type        = number
  default     = 1
  description = "Desired number of EC2 instances in the ASG."
}

variable "key_name" {
  type        = string
  default     = null
  description = "EC2 Key Pair name for SSH access. Leave null to disable SSH."
}
