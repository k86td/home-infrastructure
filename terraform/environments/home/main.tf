# Home K3S Cluster Infrastructure
# This configuration orchestrates the deployment of a K3S cluster with common setup and applications

locals {
  # Read SSH private key
  ssh_private_key = file(pathexpand(var.ssh_private_key_path))

  # Build hosts map for common setup
  all_hosts = merge(
    {
      "${var.server_host.name}" = {
        address     = var.server_host.address
        user        = var.server_host.user
        private_key = pathexpand(var.ssh_private_key_path)
      }
    },
    {
      for name, host in var.agent_hosts : name => {
        address     = host.address
        user        = host.user
        private_key = pathexpand(var.ssh_private_key_path)
      }
    }
  )

  # Agent hosts formatted for k3s-cluster module
  agent_hosts_formatted = {
    for name, host in var.agent_hosts : name => {
      address     = host.address
      user        = host.user
      private_key = pathexpand(var.ssh_private_key_path)
    }
  }
}

# ===========================
# Common Setup Module
# ===========================
# Configures baseline OS settings, users, packages, and SSH hardening

module "common_setup" {
  source = "../../modules/common-setup"

  hosts = local.all_hosts

  common_users = var.common_users

  alpine_packages = var.alpine_packages

  enable_community_repo = true

  ssh_disable_root_login = true

  doas_config = "permit nopass :wheel as root\n"

  motd_template = <<-EOT
  88         ad88888ba     ad8888ba,                   88
  88        d8"     "8b   8P'    "Y8    ,d             88
  88        Y8a     a8P  d8             88             88
  88   ,d8   "Y8aaa8P"   88,dd888bb,  MM88MMM  ,adPPYb,88
  88 ,a8"    ,d8"""8b,   88P'    `8b    88    a8"    `Y88
  8888[     d8"     "8b  88       d8    88    8b       88
  88`"Yba,  Y8a     a8P  88a     a8P    88,   "8a,   ,d88
  88   `Y8a  "Y88888P"    "Y88888P"     "Y888  `"8bbdP"Y8

  Managed by Terraform
  EOT
}

# ===========================
# K3S Cluster Module
# ===========================
# Installs and configures K3S server and agent nodes

module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  server_host = {
    address     = var.server_host.address
    user        = var.server_host.user
    private_key = pathexpand(var.ssh_private_key_path)
  }

  agent_hosts = local.agent_hosts_formatted

  k3s_version    = var.k3s_version
  k3s_token      = var.k3s_token
  k3s_use_cilium = var.k3s_use_cilium

  # Ensure common setup completes first
  depends_on_common_setup = module.common_setup.setup_complete
}

# ===========================
# Kubernetes Applications Module
# ===========================
# Deploys applications to the K3S cluster (ArgoCD, etc.)

module "kubernetes_apps" {
  source = "../../modules/kubernetes-apps"

  kubeconfig_path = module.k3s_cluster.kubeconfig_path

  install_argocd   = var.install_argocd
  argocd_namespace = "argocd"
  argocd_version   = "stable"

  # Ensure cluster is ready before deploying apps
  depends_on_cluster = module.k3s_cluster.cluster_ready
}
