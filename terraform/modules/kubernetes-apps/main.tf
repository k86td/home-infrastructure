# Kubernetes Applications Module
# Deploys applications to K3S cluster (ArgoCD, etc.)

# ArgoCD Namespace
resource "kubernetes_namespace" "argocd" {
  count = var.install_argocd ? 1 : 0

  metadata {
    name = var.argocd_namespace
  }
}

# Fetch ArgoCD manifest from GitHub
data "http" "argocd_manifest" {
  count = var.install_argocd ? 1 : 0
  url   = "https://raw.githubusercontent.com/argoproj/argo-cd/${var.argocd_version}/manifests/install.yaml"
}

# Split the manifest into individual resources
locals {
  argocd_manifests = var.install_argocd ? [
    for doc in split("---", data.http.argocd_manifest[0].response_body) :
    yamldecode(doc) if trimspace(doc) != "" && doc != null
  ] : []
}

# Apply ArgoCD manifests
resource "kubectl_manifest" "argocd" {
  count = var.install_argocd ? length(local.argocd_manifests) : 0

  yaml_body = yamlencode(local.argocd_manifests[count.index])

  depends_on = [kubernetes_namespace.argocd]

  # Override namespace if not set in manifest
  override_namespace = var.argocd_namespace
}

# Data source to verify ArgoCD deployment
data "kubernetes_service" "argocd_server" {
  count      = var.install_argocd ? 1 : 0
  depends_on = [kubectl_manifest.argocd]

  metadata {
    name      = "argocd-server"
    namespace = var.argocd_namespace
  }
}
