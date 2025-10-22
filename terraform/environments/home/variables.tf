# SSH Connection Variables
variable "ssh_private_key_path" {
  description = "Path to SSH private key for connecting to hosts"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# Host Definitions
variable "server_host" {
  description = "K3S server host configuration"
  type = object({
    name    = string
    address = string
    user    = string
  })
  default = {
    name    = "synapse-01"
    address = "192.168.0.101"
    user    = "k86td"
  }
}

variable "agent_hosts" {
  description = "K3S agent hosts configuration"
  type = map(object({
    address = string
    user    = string
  }))
  default = {
    "brainberry-01" = {
      address = "192.168.0.100"
      user    = "k86td"
    }
  }
}

# K3S Configuration
variable "k3s_version" {
  description = "K3S version to install"
  type        = string
  default     = "v1.32.3+k3s1"
}

variable "k3s_token" {
  description = "K3S cluster token (sensitive)"
  type        = string
  sensitive   = true
}

variable "k3s_use_cilium" {
  description = "Use Cilium CNI instead of Flannel"
  type        = bool
  default     = false
}

# Common Setup Variables
variable "common_users" {
  description = "Users to create on all hosts"
  type = list(object({
    name        = string
    ssh_keys    = list(string)
    groups      = optional(list(string), [])
    create_home = optional(bool, true)
  }))
  default = []
}

variable "alpine_packages" {
  description = "Alpine packages to install"
  type        = list(string)
  default     = ["tar"]
}

# ArgoCD Configuration
variable "install_argocd" {
  description = "Install ArgoCD"
  type        = bool
  default     = true
}
