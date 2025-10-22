variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
}

variable "install_argocd" {
  description = "Install ArgoCD"
  type        = bool
  default     = true
}

variable "argocd_namespace" {
  description = "Namespace for ArgoCD installation"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "ArgoCD version to install"
  type        = string
  default     = "stable"
}

variable "depends_on_cluster" {
  description = "Dependency on cluster being ready"
  type        = bool
  default     = true
}
