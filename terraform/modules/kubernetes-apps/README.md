# Kubernetes Applications Module

This Terraform module deploys applications to a K3S Kubernetes cluster. Currently supports ArgoCD for GitOps-based application deployment.

## Features

- ArgoCD installation (GitOps controller)
- Namespace management
- Manifest fetching from official repositories
- Kubernetes resource management via Terraform

## Usage

```hcl
module "kubernetes_apps" {
  source = "../../modules/kubernetes-apps"

  kubeconfig_path = module.k3s_cluster.kubeconfig_path

  install_argocd   = true
  argocd_namespace = "argocd"
  argocd_version   = "stable"

  depends_on_cluster = module.k3s_cluster.cluster_ready
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| kubernetes | ~> 2.27 |
| kubectl | ~> 1.14 |
| http | ~> 3.4 |

## Providers

| Name | Version |
|------|---------|
| kubernetes | ~> 2.27 |
| kubectl | ~> 1.14 |
| http | ~> 3.4 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| kubeconfig_path | Path to kubeconfig file | `string` | n/a | yes |
| install_argocd | Install ArgoCD | `bool` | `true` | no |
| argocd_namespace | ArgoCD namespace | `string` | `"argocd"` | no |
| argocd_version | ArgoCD version/branch | `string` | `"stable"` | no |
| depends_on_cluster | Cluster readiness dependency | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| argocd_namespace | ArgoCD namespace name |
| apps_deployed | Deployment completion flag |

## ArgoCD Installation

The module installs ArgoCD by:

1. Creating the `argocd` namespace
2. Fetching the official ArgoCD manifest from GitHub
3. Parsing the YAML manifest into individual resources
4. Applying each resource to the cluster

### ArgoCD Version Options

- `stable` - Latest stable release (recommended)
- `v2.9.3` - Specific version tag
- `master` - Latest development version (not recommended for production)

### Accessing ArgoCD

After installation, you can access ArgoCD:

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at https://localhost:8080
# Username: admin
# Password: (from command above)
```

## Provider Configuration

The kubernetes and kubectl providers must be configured in the calling module:

```hcl
provider "kubernetes" {
  config_path = module.k3s_cluster.kubeconfig_path
}

provider "kubectl" {
  config_path = module.k3s_cluster.kubeconfig_path
}
```

## Dependencies

- A running Kubernetes cluster
- Valid kubeconfig file
- Internet access to fetch manifests from GitHub

## Resource Management

The module creates:
- 1 Namespace resource
- ~30-40 Kubernetes resources (depending on ArgoCD version):
  - Deployments
  - Services
  - ServiceAccounts
  - ConfigMaps
  - Secrets
  - RBAC resources (Roles, RoleBindings, ClusterRoles, ClusterRoleBindings)
  - NetworkPolicies (optional)

## Extending the Module

To add more applications, follow the ArgoCD pattern:

```hcl
# Example: Adding Cert-Manager
resource "kubernetes_namespace" "cert_manager" {
  count = var.install_cert_manager ? 1 : 0

  metadata {
    name = "cert-manager"
  }
}

data "http" "cert_manager_manifest" {
  count = var.install_cert_manager ? 1 : 0
  url   = "https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml"
}

resource "kubectl_manifest" "cert_manager" {
  count     = var.install_cert_manager ? length(local.cert_manager_manifests) : 0
  yaml_body = yamlencode(local.cert_manager_manifests[count.index])

  depends_on = [kubernetes_namespace.cert_manager]
}
```

## Troubleshooting

### Manifest Parsing Errors
If you encounter YAML parsing errors:
- Verify the ArgoCD version is valid
- Check internet connectivity to GitHub
- Try using a specific version tag instead of `stable`

### Resources Not Creating
- Ensure kubeconfig is valid: `kubectl --kubeconfig=/path/to/kubeconfig get nodes`
- Verify cluster has sufficient resources
- Check Terraform apply output for specific resource errors

### ArgoCD Pods Not Starting
- Check pod status: `kubectl -n argocd get pods`
- View pod logs: `kubectl -n argocd logs <pod-name>`
- Verify image pull succeeds (may need image pull secrets in restricted environments)

## Notes

- The module is idempotent and can be applied multiple times
- Changing `argocd_version` will update the installation
- Manifest parsing splits YAML documents on `---` delimiter
- Empty documents are filtered out automatically
- All resources are applied to the specified namespace
