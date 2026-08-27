# ── ArgoCD via Helm ───────────────────────────────────────────────────────────
# The cluster exists (session-03-eks), so the Helm provider initializes cleanly.

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [
    yamlencode({
      server = {
        # LoadBalancer exposes the ArgoCD UI externally via an AWS LB.
        # Get the URL after apply: kubectl get svc argocd-server -n argocd
        service = { type = "LoadBalancer" }
        # Disable server-side TLS — terminate at the LB instead
        extraArgs = ["--insecure"]
      }
      configs = {
        params = { "server.insecure" = true }
      }
    })
  ]
}

# ── GitHub repo credentials (only for private repos) ─────────────────────────

resource "kubernetes_secret" "argocd_github_creds" {
  count = var.github_token != "" ? 1 : 0

  metadata {
    name      = "github-repo-creds"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = var.github_repo_url
    username = "x-token"
    password = var.github_token
  }

  depends_on = [helm_release.argocd]
}

# ── ArgoCD Application — watches k8s-manifest/ in the repo ───────────────────

resource "kubernetes_manifest" "argocd_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "vntechies-k8s-demo"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.github_repo_url
        targetRevision = var.github_branch
        path           = var.argocd_app_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "ApplyOutOfSyncOnly=true",
        ]
      }
    }
  }

  depends_on = [helm_release.argocd]
}
