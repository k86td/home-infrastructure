output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = "/tmp/k3s-kubeconfig.yaml"
}

output "k3s_server_url" {
  description = "K3S server API URL"
  value       = "https://${var.server_host.address}:6443"
}

output "cluster_ready" {
  description = "Flag indicating cluster is ready for application deployment"
  value       = true
  depends_on  = [null_resource.k3s_server, null_resource.k3s_agents]
}
