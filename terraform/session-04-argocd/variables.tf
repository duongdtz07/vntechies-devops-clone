variable "env" {
  type        = string
  default     = "dev"
  description = "Must match the env used in session-03-eks (cluster name = <env>-eks)."
}

variable "release_version" {
  type    = string
  default = "untagged"
}

variable "argocd_chart_version" {
  type        = string
  default     = "7.7.0"
  description = "ArgoCD Helm chart version. See https://artifacthub.io/packages/helm/argo/argo-cd"
}

variable "github_repo_url" {
  type        = string
  default     = "https://github.com/namtnp123/vntechies-devops"
  description = "HTTPS URL of the GitHub repo ArgoCD will sync from."
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "argocd_app_path" {
  type        = string
  default     = "k8s-manifest"
  description = "Path within the repo that ArgoCD syncs as the application source."
}

variable "github_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "GitHub personal access token for private repos. Leave empty for public repos."
}
