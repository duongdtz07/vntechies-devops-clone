env                 = "dev"
# The CI/CD IAM identity that runs session-04-argocd must be here so the
# Helm provider can authenticate to the cluster. Run:
#   aws sts get-caller-identity --query Arn --output text
# to find your ARN and uncomment the line below.
# cluster_admin_arns = [
#   "arn:aws:iam::ACCOUNT_ID:user/namtnp123",         # your IAM user
#   "arn:aws:iam::ACCOUNT_ID:role/GitHubActionsRole",  # CI/CD role (if using IAM role for GHA)
# ]
k8s_version         = "1.36"
node_instance_types = ["t3.small", "t3.medium", "t3a.small", "t3a.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 4
