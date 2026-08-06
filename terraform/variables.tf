variable "env" {
    type = string
    default = "dev"
}

variable "instance_type" {
    default = "t3.micro"
    type = string
}

variable "ami" {
    type = string
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