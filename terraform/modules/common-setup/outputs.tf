output "configured_hosts" {
  description = "List of hosts that were successfully configured"
  value       = keys(var.hosts)
}

output "setup_complete" {
  description = "Flag indicating setup completion for dependency management"
  value       = true
  depends_on  = [null_resource.common_setup]
}
