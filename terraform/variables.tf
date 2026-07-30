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