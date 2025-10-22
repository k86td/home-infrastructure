output "k3s_server_url" {
  description = "K3S server API endpoint"
  value       = module.k3s_cluster.k3s_server_url
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = module.k3s_cluster.kubeconfig_path
}

output "configured_hosts" {
  description = "List of configured hosts"
  value       = module.common_setup.configured_hosts
}

output "argocd_namespace" {
  description = "ArgoCD namespace (if installed)"
  value       = var.install_argocd ? module.kubernetes_apps.argocd_namespace : null
}
