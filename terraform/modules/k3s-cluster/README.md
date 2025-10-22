# K3S Cluster Module

This Terraform module installs and configures a K3S Kubernetes cluster on Alpine Linux hosts. It replicates the functionality of the `k86td.k3s` Ansible role.

## Features

- K3S server (control plane) installation
- K3S agent (worker) nodes installation
- Automatic cluster formation and joining
- Kubeconfig generation and distribution
- Optional Cilium CNI installation
- Kernel module configuration (overlay, br_netfilter)
- Container mount point optimization
- Cluster health verification

## Architecture

```
┌─────────────────┐
│  K3S Server     │
│  (Control Plane)│ ← Manages cluster state
└────────┬────────┘
         │
    ┌────┴─────┬────────┐
    ▼          ▼        ▼
┌────────┐ ┌────────┐ ┌────────┐
│Agent 1 │ │Agent 2 │ │Agent N │ ← Worker nodes
└────────┘ └────────┘ └────────┘
```

## Usage

```hcl
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  server_host = {
    address     = "192.168.0.101"
    user        = "k86td"
    private_key = "~/.ssh/id_rsa"
  }

  agent_hosts = {
    "agent-01" = {
      address     = "192.168.0.100"
      user        = "k86td"
      private_key = "~/.ssh/id_rsa"
    }
  }

  k3s_version    = "v1.32.3+k3s1"
  k3s_token      = "super-secret-token"
  k3s_use_cilium = false

  # Optional: depend on common setup module
  depends_on_common_setup = module.common_setup.setup_complete
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
| server_host | K3S server configuration | `object` | n/a | yes |
| agent_hosts | K3S agent configurations | `map(object)` | `{}` | no |
| k3s_version | K3S version to install | `string` | `"v1.32.3+k3s1"` | no |
| k3s_token | Cluster authentication token | `string` | n/a | yes |
| k3s_use_cilium | Use Cilium CNI instead of Flannel | `bool` | `false` | no |
| cilium_cli_version | Cilium CLI version | `string` | `"v0.18.2"` | no |
| cilium_version | Cilium version | `string` | `"1.17.2"` | no |
| disable_flannel | Disable Flannel CNI | `bool` | `false` | no |
| depends_on_common_setup | Dependency on common setup | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| kubeconfig_path | Local path to kubeconfig file |
| k3s_server_url | K3S API server URL |
| cluster_ready | Flag indicating cluster readiness |

## Installation Process

### Server Node

1. **Kernel Configuration**
   - Enable `overlay` and `br_netfilter` kernel modules
   - Configure container mount points as shared

2. **K3S Installation**
   - Download official K3S install script from https://get.k3s.io
   - Install as server with specified version and token
   - Apply Cilium flags if enabled

3. **Kubeconfig Setup**
   - Update kubeconfig with actual server IP (replaces 127.0.0.1)
   - Fetch kubeconfig locally for distribution

### Agent Nodes

1. **Kernel Configuration** (same as server)

2. **Server Connectivity**
   - Wait for server to be accessible on port 6443

3. **K3S Installation**
   - Download K3S install script
   - Install as agent pointing to server
   - Use same version and token as server

4. **Kubeconfig Distribution**
   - Receive kubeconfig from server
   - Place in `/etc/rancher/k3s/k3s.yaml`

### Cilium Installation (Optional)

If `k3s_use_cilium = true`:

1. Detect system architecture (arm64 or amd64)
2. Download Cilium CLI with checksum verification
3. Install Cilium with custom IPAM settings
4. Wait for Cilium to report healthy status

## Network Configuration

### Default (Flannel)
- CNI: Flannel
- Pod CIDR: 10.42.0.0/16 (K3S default)
- Service CIDR: 10.43.0.0/16 (K3S default)

### With Cilium
- CNI: Cilium
- Flannel: Disabled
- Network Policy: Disabled (Cilium manages)
- Pod CIDR: 10.42.0.0/16 (customizable via Cilium)

## Generated Files

| Location | Description |
|----------|-------------|
| `/etc/modules-load.d/containerd.conf` | Kernel modules to load |
| `/etc/local.d/shared-mount.start` | Mount point initialization script |
| `/etc/rancher/k3s/k3s.yaml` | Kubeconfig (on all nodes) |
| `/tmp/k3s-kubeconfig.yaml` | Local kubeconfig copy |

## Dependencies

- Alpine Linux with `doas` configured
- Internet connectivity for:
  - K3S installation script
  - K3S binary downloads
  - Cilium downloads (if enabled)
- SSH access to all nodes
- Common setup module (recommended to run first)

## Security Considerations

1. **K3S Token**: Marked as sensitive, used for cluster authentication
2. **Kubeconfig**: Contains cluster admin credentials (mode 600)
3. **SSH Keys**: Private keys required for all hosts
4. **Network**: Port 6443 must be accessible from agents to server

## Troubleshooting

### Cluster Not Forming
- Verify server is accessible on port 6443
- Check K3S token matches on all nodes
- Review `/var/log/messages` on Alpine for K3S logs

### Cilium Installation Fails
- Ensure sufficient memory (minimum 2GB recommended)
- Check architecture detection (arm64 vs amd64)
- Verify Cilium CLI download succeeds

### Agents Not Joining
- Confirm server is fully started before agents install
- Verify network connectivity: `nc -zv SERVER_IP 6443`
- Check K3S agent logs: `doas rc-service k3s-agent status`

## Resource Requirements

### Minimum (per node)
- CPU: 1 core
- RAM: 512MB (1GB with Cilium)
- Disk: 2GB free space

### Recommended
- CPU: 2 cores
- RAM: 2GB (4GB with Cilium)
- Disk: 10GB free space

## Version Compatibility

| K3S Version | Cilium Version | Terraform | Tested |
|-------------|----------------|-----------|--------|
| v1.32.3+k3s1 | 1.17.2 | >= 1.5.0 | ✓ |
| v1.31.x+k3s1 | 1.16.x | >= 1.5.0 | ✓ |

## Notes

- The module is idempotent but re-running may cause brief service disruptions
- Changing `k3s_token` will trigger reinstallation
- Kubeconfig is stored locally at `/tmp/k3s-kubeconfig.yaml`
- All nodes run with doas privilege escalation
- Installation typically takes 5-10 minutes depending on network speed
