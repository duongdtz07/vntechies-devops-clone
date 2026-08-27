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
  default     = "1.36"
  description = "EKS Kubernetes version."
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.small", "t3.medium", "t3a.small", "t3a.medium"]
  description = "Ordered list of instance types for the Spot node group. Multiple types improve Spot availability."
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

variable "cluster_admin_arns" {
  type        = list(string)
  default     = [
    "arn:aws:iam::528757789708:user/trannam",
    "arn:aws:iam::528757789708:user/terraform"
  ]
  description = "IAM user or role ARNs to grant EKS cluster-admin access. e.g. [\"arn:aws:iam::123456789012:user/alice\"]"
}
