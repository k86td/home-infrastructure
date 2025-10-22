# Home Infrastructure - Terraform Modules

This directory contains Terraform modules for deploying and managing a K3S Kubernetes cluster on bare metal Alpine Linux hosts. It provides a stable, maintainable infrastructure-as-code alternative to the Ansible-based deployment.

## Overview

This Terraform configuration manages:
- **Common Setup**: User management, SSH hardening, package installation
- **K3S Cluster**: Lightweight Kubernetes cluster (server + agents)
- **Kubernetes Applications**: GitOps with ArgoCD

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Terraform Root                         │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │         environments/home/                       │  │
│  │  (Orchestrates all modules for home cluster)    │  │
│  └──────────────────────────────────────────────────┘  │
│                         │                               │
│        ┌────────────────┼────────────────┐             │
│        ▼                ▼                ▼             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ common-  │    │   k3s-   │    │kubernetes│         │
│  │  setup   │───▶│ cluster  │───▶│   apps   │         │
│  └──────────┘    └──────────┘    └──────────┘         │
│                                                         │
│  1. User setup     2. K3S install  3. ArgoCD deploy   │
│  2. Packages       3. Cluster form 4. GitOps setup    │
│  3. SSH harden     4. Kubeconfig                       │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  Physical/Virtual Infrastructure│
        │                                 │
        │  ┌──────────┐   ┌──────────┐  │
        │  │ Server   │   │ Agent(s) │  │
        │  │synapse-01│◀──│brainberry│  │
        │  │:6443     │   │    -01   │  │
        │  └──────────┘   └──────────┘  │
        │  Alpine Linux   Alpine Linux  │
        └────────────────────────────────┘
```

## Directory Structure

```
terraform/
├── modules/                      # Reusable Terraform modules
│   ├── common-setup/            # User mgmt, SSH, packages
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   ├── k3s-cluster/             # K3S installation & clustering
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   └── kubernetes-apps/         # K8s application deployment
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
├── environments/
│   └── home/                    # Home cluster environment
│       ├── main.tf              # Module orchestration
│       ├── variables.tf         # Environment variables
│       ├── outputs.tf           # Environment outputs
│       ├── versions.tf          # Provider config
│       ├── terraform.tfvars.example
│       └── README.md
├── .gitignore                   # Terraform artifacts
└── README.md                    # This file
```

## Quick Start

### Prerequisites

1. **Terraform** >= 1.5.0
   ```bash
   # Install via package manager or from https://www.terraform.io/downloads
   terraform version
   ```

2. **SSH Access** to all target hosts
   - Private key configured
   - Initial root or sudo access

3. **Target Hosts** running Alpine Linux
   - Network connectivity between hosts
   - Internet access for package downloads

### Initial Setup

1. **Navigate to the home environment**
   ```bash
   cd terraform/environments/home
   ```

2. **Create terraform.tfvars from example**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars with your values**
   ```bash
   # Edit with your preferred editor
   vim terraform.tfvars
   ```

   Key values to update:
   - `ssh_private_key_path`: Path to your SSH private key
   - `server_host`: Server node details (IP, user)
   - `agent_hosts`: Agent node details
   - `k3s_token`: Secure cluster token (generate with `openssl rand -base64 32`)

4. **Initialize Terraform**
   ```bash
   terraform init
   ```

5. **Review the plan**
   ```bash
   terraform plan
   ```

6. **Apply the configuration**
   ```bash
   terraform apply
   ```

7. **Access your cluster**
   ```bash
   export KUBECONFIG=/tmp/k3s-kubeconfig.yaml
   kubectl get nodes
   ```

## Module Dependency Flow

The modules are designed to run in sequence with explicit dependencies:

```
common-setup
    │
    └─▶ k3s-cluster
           │
           └─▶ kubernetes-apps
```

1. **common-setup** runs first
   - Creates users and SSH keys
   - Installs packages
   - Hardens SSH configuration
   - Configures doas

2. **k3s-cluster** runs after common-setup
   - Installs K3S on server node
   - Joins agent nodes to cluster
   - Generates and distributes kubeconfig
   - Optionally installs Cilium

3. **kubernetes-apps** runs after cluster is ready
   - Deploys ArgoCD for GitOps
   - Can deploy additional applications

## Configuration Examples

### Minimal Configuration

```hcl
# terraform.tfvars
ssh_private_key_path = "~/.ssh/id_rsa"

server_host = {
  name    = "server-01"
  address = "192.168.1.10"
  user    = "root"
}

k3s_token = "my-super-secret-token"
```

### Full Configuration

```hcl
# terraform.tfvars
ssh_private_key_path = "~/.ssh/id_rsa"

server_host = {
  name    = "synapse-01"
  address = "192.168.0.101"
  user    = "k86td"
}

agent_hosts = {
  "brainberry-01" = {
    address = "192.168.0.100"
    user    = "k86td"
  }
  "agent-02" = {
    address = "192.168.0.102"
    user    = "k86td"
  }
}

k3s_version    = "v1.32.3+k3s1"
k3s_token      = "your-secure-token-here"
k3s_use_cilium = false

common_users = [
  {
    name     = "k86td"
    ssh_keys = ["https://github.com/k86td.keys"]
    groups   = ["wheel"]
  }
]

alpine_packages = ["tar", "curl", "bash", "vim"]

install_argocd = true
```

## Usage Scenarios

### Deploy New Cluster

```bash
cd terraform/environments/home
terraform init
terraform apply
```

### Update K3S Version

```bash
# Edit terraform.tfvars, change k3s_version
vim terraform.tfvars

# Apply changes (will trigger K3S reinstall)
terraform apply
```

### Add New Agent Node

```bash
# Edit terraform.tfvars, add to agent_hosts
vim terraform.tfvars

# Apply to add new node
terraform apply
```

### Install Additional Packages

```bash
# Edit terraform.tfvars, update alpine_packages
vim terraform.tfvars

# Apply changes
terraform apply
```

## State Management

### Local State (Default)

By default, Terraform stores state in `terraform.tfstate` locally.

**Important**: Add `terraform.tfstate*` to `.gitignore` to avoid committing sensitive data.

### Remote State (Recommended for Teams)

For production or team environments, use remote state:

#### Terraform Cloud

```hcl
# In versions.tf
terraform {
  cloud {
    organization = "your-org"
    workspaces {
      name = "home-k3s"
    }
  }
}
```

#### S3 Backend

```hcl
# In versions.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "home-k3s/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Module Documentation

Each module has comprehensive documentation:

- **[common-setup](modules/common-setup/README.md)**: OS baseline configuration
- **[k3s-cluster](modules/k3s-cluster/README.md)**: K3S installation and clustering
- **[kubernetes-apps](modules/kubernetes-apps/README.md)**: Application deployment

## Comparison with Ansible

| Aspect | Ansible | Terraform |
|--------|---------|-----------|
| **Provisioning** | `ansible-playbook` | `terraform apply` |
| **Idempotency** | Built-in | Managed via triggers |
| **State** | Stateless | Stateful |
| **Secrets** | Ansible Vault | Terraform variables (sensitive) |
| **Dependencies** | Task ordering | Module dependencies |
| **Inventory** | `inventories/home.yaml` | `terraform.tfvars` |
| **Roles** | `k86td.common`, `k86td.k3s` | Modules |

### Migration from Ansible

If you're currently using the Ansible setup:

1. Both can coexist (use different hosts or manage different aspects)
2. Terraform can manage infrastructure, Ansible can manage apps
3. For full migration:
   - Map Ansible variables to Terraform variables
   - Convert encrypted vault values to Terraform variables
   - Run Terraform on same hosts (idempotent operations)

## Troubleshooting

### Connection Issues

```bash
# Test SSH connectivity
ssh -i ~/.ssh/id_rsa user@host

# Verify SSH key permissions
chmod 600 ~/.ssh/id_rsa
```

### State Corruption

```bash
# Create backup
cp terraform.tfstate terraform.tfstate.backup

# If needed, refresh state
terraform refresh
```

### Module Errors

```bash
# Re-initialize (updates providers/modules)
terraform init -upgrade

# Validate configuration
terraform validate
```

### Destroy and Recreate

```bash
# Destroy all resources
terraform destroy

# Fresh deployment
terraform apply
```

## Security Considerations

1. **SSH Keys**: Keep private keys secure, never commit to Git
2. **K3S Token**: Generate strong random tokens
3. **Secrets**: Use sensitive variable marking
4. **State Files**: Contain sensitive data, use remote state with encryption
5. **RBAC**: ArgoCD has cluster-admin by default, configure RBAC as needed

## Contributing

To add new modules or improve existing ones:

1. Follow the standard module structure (see Module Structure below)
2. Include comprehensive README.md
3. Add examples in `examples/` subdirectory
4. Document all variables and outputs
5. Test with `terraform validate` and `terraform plan`

### Module Structure Standard

```
module-name/
├── main.tf          # Main resources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── versions.tf      # Provider requirements
├── README.md        # Documentation
└── examples/        # Usage examples (optional)
```

## Maintenance

### Regular Updates

```bash
# Update provider versions
terraform init -upgrade

# Check for drift
terraform plan

# Apply any drift corrections
terraform apply
```

### Backup Strategy

Recommended to backup:
- `terraform.tfvars` (configuration)
- `terraform.tfstate` (state file)
- Generated kubeconfig files

## Support and Resources

- **Terraform Docs**: https://www.terraform.io/docs
- **K3S Docs**: https://docs.k3s.io
- **ArgoCD Docs**: https://argo-cd.readthedocs.io
- **Alpine Linux**: https://wiki.alpinelinux.org

## License

Same license as the parent repository (check root LICENSE file).

## Version History

- **v1.0.0** - Initial Terraform module implementation
  - Common setup module
  - K3S cluster module
  - Kubernetes apps module (ArgoCD)
  - Home environment configuration
