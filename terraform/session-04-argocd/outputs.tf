output "argocd_initial_password_command" {
  value       = "kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode"
  description = "Run this to retrieve the initial ArgoCD admin password."
}

output "argocd_server_url_command" {
  value       = "kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
  description = "Run this to get the ArgoCD server LoadBalancer URL."
}
