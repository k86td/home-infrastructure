# Common Setup Module

This Terraform module provides common baseline configuration for Alpine Linux hosts. It replicates the functionality of the `k86td.common` Ansible role.

## Features

- User management with SSH key distribution
- Package installation via APK
- SSH hardening (disable root login)
- doas (sudo alternative) configuration
- Alpine community repository enablement
- Message of the Day (MOTD) customization

## Usage

```hcl
module "common_setup" {
  source = "../../modules/common-setup"

  hosts = {
    "server-01" = {
      address     = "192.168.0.101"
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
    "agent-01" = {
      address     = "192.168.0.100"
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  common_users = [
    {
      name     = "k86td"
      ssh_keys = ["https://github.com/k86td.keys"]
      groups   = ["wheel"]
    }
  ]

  alpine_packages = ["tar", "curl", "bash"]

  doas_config = "permit nopass :wheel as root\n"

  ssh_disable_root_login = true

  enable_community_repo = true

  motd_template = <<-EOT
  Welcome to the K3S cluster!
  Managed by Terraform
  EOT
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| null | ~> 3.2 |

## Providers

| Name | Version |
|------|---------|
| null | ~> 3.2 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| hosts | Map of hosts to configure | `map(object)` | n/a | yes |
| common_users | List of users to create | `list(object)` | `[]` | no |
| alpine_packages | APK packages to install | `list(string)` | `["tar"]` | no |
| enable_community_repo | Enable Alpine community repository | `bool` | `true` | no |
| ssh_disable_root_login | Disable root SSH login | `bool` | `true` | no |
| doas_config | doas configuration content | `string` | `"permit persist :wheel\n"` | no |
| motd_template | Message of the day template | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| configured_hosts | List of hosts that were configured |
| setup_complete | Flag for dependency management |

## SSH Key Management

The module supports two ways to provide SSH keys:

1. **GitHub URL**: Fetch public keys from GitHub (e.g., `https://github.com/username.keys`)
2. **Direct keys**: Provide the actual SSH public key string

Example:
```hcl
common_users = [
  {
    name     = "john"
    ssh_keys = ["https://github.com/john.keys"]  # Fetch from GitHub
    groups   = ["wheel"]
  },
  {
    name     = "jane"
    ssh_keys = ["ssh-rsa AAAAB3NzaC1yc2EAAA... jane@laptop"]  # Direct key
    groups   = []
  }
]
```

## Dependencies

This module assumes:
- Alpine Linux operating system
- `doas` is available on the system
- SSH access to the hosts
- Internet connectivity for package installation and GitHub key fetching

## Notes

- The module uses `doas` instead of `sudo` (Alpine Linux convention)
- All operations are idempotent and can be run multiple times safely
- The module triggers re-execution when user, package, or configuration changes are detected
- SSH keys from GitHub are appended to existing authorized_keys
