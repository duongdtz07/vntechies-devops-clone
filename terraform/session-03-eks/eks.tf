resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.k8s_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = concat(
      [for s in aws_subnet.public : s.id],
      [for s in aws_subnet.private : s.id]
    )
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # Enable control-plane logging — useful for teaching
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = merge(local.common_tags, {
    Name = local.cluster_name
  })

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# ── Managed Node Group (private subnets only) ─────────────────────────────────

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.env}-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn

  # Nodes go into private subnets — no direct internet exposure
  subnet_ids = [for s in aws_subnet.private : s.id]

  instance_types = [var.node_instance_type]
  # AL2023 is the current-gen EKS-optimised AMI required for Kubernetes 1.30+.
  # AL2 (the implicit default) does not have supported images for 1.30+.
  ami_type = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(local.common_tags, {
    Name = "${var.env}-node-group"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly,
  ]
}

# ── EKS Add-ons ───────────────────────────────────────────────────────────────

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  tags = local.common_tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  tags       = local.common_tags
  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  tags = local.common_tags
}

# EBS CSI driver — required to provision EBS-backed PersistentVolumes (e.g. MongoDB storage)
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"

  tags       = local.common_tags
  depends_on = [aws_eks_node_group.main]
}
