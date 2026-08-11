variable "env" {
  type    = string
  default = "dev"
}

variable "release_version" {
  type        = string
  default     = "untagged"
  description = "Git release tag applied to all resources (e.g. v1.2.3). Set automatically by CI; defaults to 'untagged' for local runs."
}

variable "instance_type" {
  default = "t3.micro"
  type    = string
}

variable "ami" {
  type    = string
  default = "ami-01b70d44184a858e8"
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "asg_desired_capacity" {
  type    = number
  default = 1
}