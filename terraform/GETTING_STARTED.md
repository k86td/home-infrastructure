# Getting Started with Terraform Infrastructure

This guide walks you through validating and deploying the Terraform-based infrastructure.

## Prerequisites

### 1. Install Terraform

#### Option A: Using Nix Flake (Recommended)

The repository includes a Nix flake with all required tools:

```bash
# Navigate to repository root
cd /home/user/home-infrastructure

# Enter Nix development shell
nix develop

# Verify tools are available
terraform version
ansible --version
kubectl version --client
```

#### Option B: Install Terraform Directly

**macOS:**
```bash
brew install terraform
```

**Linux (Ubuntu/Debian):**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Linux (RHEL/CentOS/Fedora):**
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install terraform
```

**Manual Installation:**
```bash
# Download from https://www.terraform.io/downloads
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version
```

### 2. SSH Access

Ensure you have SSH access to your target hosts:

```bash
# Test connectivity
ssh -i ~/.ssh/id_rsa user@192.168.0.101

# If you need to generate a key
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Copy key to hosts (if initial setup)
ssh-copy-id -i ~/.ssh/id_rsa.pub user@192.168.0.101
```

### 3. Target Hosts

Ensure your Alpine Linux hosts are:
- Running and accessible via SSH
- Connected to the internet
- Have `doas` or `sudo` configured for your user

## Validation Steps

### 1. Navigate to Environment

```bash
cd terraform/environments/home
```

### 2. Create Configuration

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Required changes:**
- `k3s_token`: Generate with `openssl rand -base64 32`
- Update host IPs if different from defaults
- Update usernames if different from defaults
- Verify SSH key path

### 3. Initialize Terraform

```bash
terraform init
```

**Expected output:**
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/null versions matching "~> 3.2"...
- Finding hashicorp/kubernetes versions matching "~> 2.27"...
- Finding gavinbunney/kubectl versions matching "~> 1.14"...
- Finding hashicorp/http versions matching "~> 3.4"...
- Installing hashicorp/null v3.2.x...
- Installing hashicorp/kubernetes v2.27.x...
- Installing gavinbunney/kubectl v1.14.x...
- Installing hashicorp/http v3.4.x...

Terraform has been successfully initialized!
```

### 4. Validate Configuration

```bash
terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

### 5. Format Check

```bash
terraform fmt -check -recursive
```

This ensures consistent formatting across all Terraform files.

### 6. Review Plan

```bash
terraform plan
```

**Expected resources to be created:**
- ~6-10 null_resources (common setup for all hosts)
- ~4-6 null_resources (K3S server and agents)
- 1 kubernetes_namespace (argocd)
- ~30-40 kubectl_manifests (ArgoCD components)

**Total resources:** Approximately 40-60 resources

### 7. Dry Run Validation

To validate without actually making changes:

```bash
terraform plan -out=tfplan
terraform show tfplan
```

Review the plan carefully. You should see:

**Module: common_setup**
- User creation commands
- Package installation
- SSH hardening
- doas configuration

**Module: k3s_cluster**
- Kernel module setup
- K3S server installation
- K3S agent installation
- Kubeconfig fetching

**Module: kubernetes_apps**
- ArgoCD namespace creation
- ArgoCD manifest application

## Common Validation Errors

### Error: Invalid SSH Key Path

```
Error: file: open ~/.ssh/id_rsa: no such file or directory
```

**Fix:** Update `ssh_private_key_path` in terraform.tfvars with correct path.

### Error: Module Not Found

```
Error: Module not installed
```

**Fix:** Run `terraform init` to download modules.

### Error: Provider Version Conflict

```
Error: Failed to query available provider packages
```

**Fix:** Run `terraform init -upgrade` to update providers.

### Error: Invalid Configuration

```
Error: Missing required argument
```

**Fix:** Check that all required variables are set in terraform.tfvars.

## Deployment Checklist

Before running `terraform apply`, ensure:

- [ ] SSH connectivity to all hosts verified
- [ ] Hosts are running Alpine Linux
- [ ] `doas` is configured on hosts
- [ ] Internet connectivity from hosts
- [ ] K3S token is strong and random
- [ ] SSH private key has correct permissions (600)
- [ ] Backup existing configurations (if any)
- [ ] Reviewed terraform plan output
- [ ] Sufficient disk space on hosts (2GB+)
- [ ] Sufficient RAM on hosts (512MB+, 2GB+ for Cilium)

## First Deployment

### 1. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

### 2. Monitor Progress

The deployment will show real-time progress:

```
module.common_setup.null_resource.common_setup["synapse-01"]: Creating...
module.common_setup.null_resource.common_setup["brainberry-01"]: Creating...
...
module.k3s_cluster.null_resource.k3s_server: Creating...
...
module.kubernetes_apps.kubernetes_namespace.argocd[0]: Creating...
```

**Total time:** 10-15 minutes

### 3. Verify Deployment

```bash
# Check outputs
terraform output

# Verify kubeconfig
export KUBECONFIG=/tmp/k3s-kubeconfig.yaml
kubectl get nodes
kubectl get pods -A
```

**Expected nodes:**
```
NAME             STATUS   ROLES                  AGE   VERSION
synapse-01       Ready    control-plane,master   5m    v1.32.3+k3s1
brainberry-01    Ready    <none>                 3m    v1.32.3+k3s1
```

**Expected ArgoCD pods:**
```
NAME                                 READY   STATUS    RESTARTS   AGE
argocd-server-xxxxx                  1/1     Running   0          2m
argocd-repo-server-xxxxx             1/1     Running   0          2m
argocd-application-controller-xxxxx  1/1     Running   0          2m
...
```

## Post-Deployment

### Access ArgoCD

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Username: admin
# Password: <from above command>
```

### Save Important Files

```bash
# Backup configuration
cp terraform.tfvars terraform.tfvars.backup

# Backup state
cp terraform.tfstate terraform.tfstate.backup

# Backup kubeconfig
cp /tmp/k3s-kubeconfig.yaml ~/.kube/home-k3s-config
```

## Troubleshooting Validation

### Terraform Init Fails

```bash
# Clear cache
rm -rf .terraform .terraform.lock.hcl

# Re-initialize
terraform init
```

### Provider Download Fails

```bash
# Use a mirror
terraform init -plugin-dir=/path/to/plugins
```

### Syntax Errors

```bash
# Check specific module
cd ../../modules/common-setup
terraform validate

cd ../../modules/k3s-cluster
terraform validate

cd ../../modules/kubernetes-apps
terraform validate
```

### Permission Issues

```bash
# Fix SSH key permissions
chmod 600 ~/.ssh/id_rsa

# Fix directory permissions
chmod 755 terraform/
```

## Testing Individual Modules

To test modules independently:

### Test common-setup

```bash
cd ../../modules/common-setup

cat > test.tf << 'EOF'
module "test" {
  source = "./"

  hosts = {
    "test-host" = {
      address     = "192.168.0.101"
      user        = "root"
      private_key = "~/.ssh/id_rsa"
    }
  }
}
EOF

terraform init
terraform validate
rm test.tf
```

### Test k3s-cluster

```bash
cd ../../modules/k3s-cluster

cat > test.tf << 'EOF'
module "test" {
  source = "./"

  server_host = {
    address     = "192.168.0.101"
    user        = "root"
    private_key = "~/.ssh/id_rsa"
  }

  k3s_token = "test-token"
}
EOF

terraform init
terraform validate
rm test.tf
```

## Next Steps

After successful validation:

1. **Review the plan**: `terraform plan > plan.txt`
2. **Deploy**: `terraform apply`
3. **Verify**: Check all outputs and cluster health
4. **Document**: Record any custom changes in notes
5. **Backup**: Save terraform.tfvars and state files

## Additional Resources

- **Main README**: ../README.md
- **Module Documentation**:
  - common-setup: ../modules/common-setup/README.md
  - k3s-cluster: ../modules/k3s-cluster/README.md
  - kubernetes-apps: ../modules/kubernetes-apps/README.md
- **Environment README**: README.md
- **Terraform Documentation**: https://www.terraform.io/docs
- **K3S Documentation**: https://docs.k3s.io

## Support

If you encounter issues:

1. Check Terraform logs: `TF_LOG=DEBUG terraform plan`
2. Verify SSH connectivity manually
3. Review module READMEs
4. Check K3S logs on hosts: `doas tail -f /var/log/messages`
5. Validate syntax: `terraform validate`

## Clean Up

To remove all infrastructure:

```bash
terraform destroy
```

**Warning:** This will completely remove the K3S cluster and all applications!
