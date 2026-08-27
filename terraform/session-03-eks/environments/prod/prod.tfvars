env                 = "prod"
# cluster_admin_arns = ["arn:aws:iam::ACCOUNT_ID:user/your-iam-user"]
k8s_version         = "1.36"
node_instance_types = ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]
node_desired_size   = 3
node_min_size       = 2
node_max_size       = 6
