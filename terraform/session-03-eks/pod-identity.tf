# ── EKS Pod Identity for EBS CSI Driver ──────────────────────────────────────
# Pod Identity injects AWS credentials directly into the driver pod so it can
# make EC2 API calls. This is the modern alternative to IRSA — no OIDC
# provider or TLS certificate data source needed.

# The agent addon must run on every node to intercept credential requests.
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"

  tags       = local.common_tags
  depends_on = [aws_eks_node_group.main]
}

# IAM role the EBS CSI driver pod will assume via Pod Identity.
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${local.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Bind the driver's service account to the IAM role.
resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver.arn

  tags       = local.common_tags
  depends_on = [aws_eks_addon.pod_identity_agent]
}
