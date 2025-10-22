# Home Environment - K3S Cluster

This environment deploys a K3S Kubernetes cluster for the home lab on Alpine Linux hosts.

## Current Configuration

- **Server Node**: synapse-01 (192.168.0.101)
- **Agent Nodes**: brainberry-01 (192.168.0.100)
- **K3S Version**: v1.32.3+k3s1
- **CNI**: Flannel (Cilium optional, requires more memory)
- **GitOps**: ArgoCD

## Quick Start

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

Update the following required values:
- `ssh_private_key_path`: Path to your SSH private key
- `k3s_token`: Generate with `openssl rand -base64 32`

### 2. Initialize Terraform

```bash
terraform init
```

This will download required providers:
- hashicorp/null
- hashicorp/kubernetes
- gavinbunney/kubectl
- hashicorp/http

### 3. Review Plan

```bash
terraform plan
```

This will show all resources that will be created:
- null_resource for common setup (per host)
- null_resource for K3S installation (server + agents)
- kubernetes_namespace for ArgoCD
- kubectl_manifest for ArgoCD components

### 4. Deploy

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes approximately 5-10 minutes.

### 5. Access Cluster

```bash
export KUBECONFIG=/tmp/k3s-kubeconfig.yaml
kubectl get nodes
kubectl get pods -A
```

## Variable Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `k3s_token` | Cluster authentication token | `"abc123..."` |

### Optional Variables (with defaults)

| Variable | Default | Description |
|----------|---------|-------------|
| `ssh_private_key_path` | `~/.ssh/id_rsa` | SSH private key path |
| `k3s_version` | `v1.32.3+k3s1` | K3S version to install |
| `k3s_use_cilium` | `false` | Use Cilium CNI (requires 2GB+ RAM) |
| `install_argocd` | `true` | Install ArgoCD |
| `alpine_packages` | `["tar"]` | APK packages to install |

### Host Configuration

Default hosts (customize in terraform.tfvars):

```hcl
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
}
```

### User Management

Default user configuration (fetch SSH keys from GitHub):

```hcl
common_users = [
  {
    name     = "k86td"
    ssh_keys = ["https://github.com/k86td.keys"]
    groups   = ["wheel"]
  }
]
```

## Outputs

After successful deployment:

```bash
terraform output
```

| Output | Description |
|--------|-------------|
| `k3s_server_url` | K3S API server endpoint |
| `kubeconfig_path` | Path to kubeconfig file |
| `configured_hosts` | List of configured hosts |
| `argocd_namespace` | ArgoCD namespace (if installed) |

## Common Tasks

### Access ArgoCD

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser to https://localhost:8080
# Username: admin
# Password: (from command above)
```

### Add New Agent Node

1. Edit `terraform.tfvars`:
   ```hcl
   agent_hosts = {
     "brainberry-01" = { address = "192.168.0.100", user = "k86td" }
     "new-agent-01" = { address = "192.168.0.103", user = "k86td" }
   }
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

### Update K3S Version

1. Edit `terraform.tfvars`:
   ```hcl
   k3s_version = "v1.33.0+k3s1"
   ```

2. Apply (will reinstall K3S):
   ```bash
   terraform apply
   ```

### Enable Cilium CNI

**Note**: Requires at least 2GB RAM per node.

1. Edit `terraform.tfvars`:
   ```hcl
   k3s_use_cilium = true
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

### Install Additional Packages

1. Edit `terraform.tfvars`:
   ```hcl
   alpine_packages = ["tar", "curl", "vim", "htop"]
   ```

2. Apply:
   ```bash
   terraform apply
   ```

## Deployment Stages

The deployment follows this sequence:

### Stage 1: Common Setup (≈2 min)
- Creates users on all hosts
- Fetches SSH keys from GitHub
- Installs Alpine packages
- Configures doas
- Hardens SSH
- Sets MOTD

### Stage 2: K3S Server (≈2-3 min)
- Configures kernel modules
- Downloads K3S install script
- Installs K3S server
- Waits for API server to be ready
- Updates kubeconfig

### Stage 3: K3S Agents (≈2-3 min per agent)
- Configures kernel modules
- Waits for server availability
- Installs K3S agent
- Joins cluster

### Stage 4: Kubeconfig Distribution (≈1 min)
- Fetches kubeconfig from server
- Distributes to all nodes

### Stage 5: Kubernetes Apps (≈2 min)
- Creates ArgoCD namespace
- Fetches ArgoCD manifests
- Deploys ArgoCD components
- Waits for readiness

**Total Time**: Approximately 10-15 minutes for full deployment

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| Kubeconfig (local) | `/tmp/k3s-kubeconfig.yaml` | Local cluster access |
| Kubeconfig (remote) | `/etc/rancher/k3s/k3s.yaml` | On all cluster nodes |
| K3S config | `/etc/rancher/k3s/` | K3S configuration |
| doas config | `/etc/doas.conf` | Privilege escalation |
| MOTD | `/etc/motd` | Login message |

## Troubleshooting

### SSH Connection Fails

```bash
# Test SSH manually
ssh -i ~/.ssh/id_rsa k86td@192.168.0.101

# Check key permissions
chmod 600 ~/.ssh/id_rsa

# Verify host is reachable
ping 192.168.0.101
```

### K3S Server Won't Start

```bash
# SSH to server
ssh k86td@192.168.0.101

# Check K3S service
doas rc-service k3s status

# View logs
doas tail -f /var/log/messages | grep k3s

# Manually test K3S
doas kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes
```

### Agents Won't Join

```bash
# Verify server is accessible from agent
ssh k86td@192.168.0.100
nc -zv 192.168.0.101 6443

# Check K3S agent service
doas rc-service k3s-agent status

# View agent logs
doas tail -f /var/log/messages | grep k3s
```

### ArgoCD Pods Not Starting

```bash
# Check pod status
kubectl -n argocd get pods

# Describe problematic pod
kubectl -n argocd describe pod <pod-name>

# View logs
kubectl -n argocd logs <pod-name>

# Check resource availability
kubectl top nodes
```

### State File Issues

```bash
# Backup current state
cp terraform.tfstate terraform.tfstate.backup

# Refresh state from actual infrastructure
terraform refresh

# If state is corrupt, import resources manually
terraform import module.common_setup.null_resource.common_setup[\"synapse-01\"] <resource-id>
```

## Maintenance

### Regular Updates

```bash
# Update providers
terraform init -upgrade

# Check for configuration drift
terraform plan

# Apply any necessary changes
terraform apply
```

### Backup

Backup these files regularly:
```bash
# Configuration
terraform.tfvars

# State (contains sensitive data!)
terraform.tfstate
terraform.tfstate.backup

# Kubeconfig
/tmp/k3s-kubeconfig.yaml
```

### Destroy Cluster

**Warning**: This will completely remove the K3S cluster!

```bash
terraform destroy
```

## Security Notes

1. **K3S Token**: Keep secret, regenerate periodically
2. **SSH Keys**: Never commit private keys to Git
3. **State Files**: Contain tokens and sensitive data
4. **Kubeconfig**: Contains cluster admin credentials
5. **ArgoCD Admin**: Change default password immediately

## Network Requirements

### Firewall Rules

Ensure these ports are open:

| Port | Protocol | Source | Destination | Purpose |
|------|----------|--------|-------------|---------|
| 22 | TCP | Your machine | All nodes | SSH |
| 6443 | TCP | Agents | Server | K3S API |
| 10250 | TCP | All nodes | All nodes | Kubelet |
| 8472 | UDP | All nodes | All nodes | Flannel VXLAN |

### DNS

Not required, but recommended:
- Add hosts to `/etc/hosts` for easy access
- Configure local DNS server for name resolution

## Resource Requirements

### Minimum (per node)
- CPU: 1 core
- RAM: 512MB
- Disk: 2GB
- Network: 100Mbps

### Recommended
- CPU: 2 cores
- RAM: 2GB (4GB with Cilium)
- Disk: 20GB SSD
- Network: 1Gbps

### Current Setup
- **synapse-01**: Raspberry Pi 4 (4GB RAM, 4 cores)
- **brainberry-01**: Raspberry Pi 4 (4GB RAM, 4 cores)

## Next Steps

After deployment:

1. **Configure ArgoCD Applications**
   ```bash
   kubectl apply -f your-argocd-app.yaml
   ```

2. **Deploy Your Applications**
   - Use ArgoCD for GitOps
   - Or use kubectl/helm directly

3. **Set Up Monitoring**
   - Prometheus + Grafana
   - K8s Dashboard

4. **Configure Ingress**
   - Traefik (included with K3S)
   - Or NGINX Ingress

5. **Set Up Persistent Storage**
   - Local path provisioner (included)
   - Or external NFS/Ceph

## Support

For issues or questions:
1. Check module READMEs in `../../modules/`
2. Review Terraform logs: `TF_LOG=DEBUG terraform apply`
3. Check K3S documentation: https://docs.k3s.io
4. Review ArgoCD documentation: https://argo-cd.readthedocs.io
