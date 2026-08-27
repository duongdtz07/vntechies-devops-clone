output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  value = aws_eks_cluster.main.version
}

output "kubeconfig_command" {
  value       = "aws eks update-kubeconfig --region ap-southeast-1 --name ${aws_eks_cluster.main.name}"
  description = "Run this command to configure kubectl for this cluster."
}
