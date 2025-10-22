variable "server_host" {
  description = "K3S server host configuration"
  type = object({
    address     = string
    user        = string
    private_key = string
  })
}

variable "agent_hosts" {
  description = "Map of K3S agent hosts"
  type = map(object({
    address     = string
    user        = string
    private_key = string
  }))
  default = {}
}

variable "k3s_version" {
  description = "K3S version to install"
  type        = string
  default     = "v1.32.3+k3s1"
}

variable "k3s_token" {
  description = "K3S cluster token for node authentication"
  type        = string
  sensitive   = true
}

variable "k3s_use_cilium" {
  description = "Install Cilium CNI instead of default Flannel"
  type        = bool
  default     = false
}

variable "cilium_cli_version" {
  description = "Cilium CLI version"
  type        = string
  default     = "v0.18.2"
}

variable "cilium_version" {
  description = "Cilium version"
  type        = string
  default     = "1.17.2"
}

variable "disable_flannel" {
  description = "Disable Flannel CNI (required for Cilium)"
  type        = bool
  default     = false
}

variable "depends_on_common_setup" {
  description = "Dependency on common setup module completion"
  type        = bool
  default     = true
}
