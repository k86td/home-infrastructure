output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = var.install_argocd ? kubernetes_namespace.argocd[0].metadata[0].name : null
}

output "apps_deployed" {
  description = "Flag indicating apps are deployed"
  value       = true
  depends_on  = [kubectl_manifest.argocd]
}
