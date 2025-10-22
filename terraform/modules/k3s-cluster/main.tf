# K3S Cluster Module
# Replicates k86td.k3s Ansible role functionality

locals {
  # Build K3S installation flags
  cilium_flags       = var.k3s_use_cilium ? "--flannel-backend=none --disable-network-policy" : ""
  disable_flannel    = var.disable_flannel ? "--disable-network-policy" : ""
  server_exec_flags  = "server ${local.cilium_flags} ${local.disable_flannel}"
  agent_exec_flags   = "agent --server https://${var.server_host.address}:6443 ${local.cilium_flags}"
  kubeconfig_path    = "/etc/rancher/k3s/k3s.yaml"
  local_kubeconfig   = "/tmp/k3s-kubeconfig.yaml"
}

# ===========================
# K3S Server Installation
# ===========================

resource "null_resource" "k3s_server" {
  connection {
    type        = "ssh"
    host        = var.server_host.address
    user        = var.server_host.user
    private_key = file(var.server_host.private_key)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '=== Installing K3S Server on ${var.server_host.address} ==='",

      # Enable kernel modules
      "echo 'Configuring kernel modules...'",
      "cat <<'EOF' | doas tee /etc/modules-load.d/containerd.conf > /dev/null",
      "overlay",
      "br_netfilter",
      "EOF",
      "doas modprobe overlay 2>/dev/null || true",
      "doas modprobe br_netfilter 2>/dev/null || true",

      # Make mount points shared
      "echo 'Configuring mount points...'",
      "doas mount --make-rshared / 2>/dev/null || true",
      "doas rc-update add local default 2>/dev/null || true",
      "cat <<'EOF' | doas tee /etc/local.d/shared-mount.start > /dev/null",
      "#!/bin/sh",
      "mount --make-rshared /",
      "EOF",
      "doas chmod +x /etc/local.d/shared-mount.start",

      # Download K3S install script
      "echo 'Downloading K3S install script...'",
      "curl -sfL https://get.k3s.io -o /tmp/k3s_install.sh",
      "chmod +x /tmp/k3s_install.sh",

      # Install K3S server
      "echo 'Installing K3S ${var.k3s_version}...'",
      "INSTALL_K3S_VERSION='${var.k3s_version}' K3S_TOKEN='${var.k3s_token}' INSTALL_K3S_EXEC='${local.server_exec_flags}' doas sh /tmp/k3s_install.sh",

      # Wait for K3S to be ready
      "echo 'Waiting for K3S server to be ready...'",
      "for i in {1..30}; do doas kubectl get nodes && break || sleep 10; done",

      # Update kubeconfig with correct server address
      "echo 'Updating kubeconfig...'",
      "doas sed -i 's/127.0.0.1/${var.server_host.address}/g' ${local.kubeconfig_path}",

      "echo '=== K3S Server installation complete ==='",
    ]
  }

  triggers = {
    version        = var.k3s_version
    token          = md5(var.k3s_token)
    use_cilium     = var.k3s_use_cilium
    common_setup   = var.depends_on_common_setup
  }
}

# Fetch kubeconfig from server
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [null_resource.k3s_server]

  connection {
    type        = "ssh"
    host        = var.server_host.address
    user        = var.server_host.user
    private_key = file(var.server_host.private_key)
    timeout     = "2m"
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp -i ${var.server_host.private_key} \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          ${var.server_host.user}@${var.server_host.address}:${local.kubeconfig_path} \
          ${local.local_kubeconfig}
    EOT
  }

  triggers = {
    server_ready = null_resource.k3s_server.id
  }
}

# ===========================
# K3S Agent Installation
# ===========================

resource "null_resource" "k3s_agents" {
  for_each   = var.agent_hosts
  depends_on = [null_resource.k3s_server]

  connection {
    type        = "ssh"
    host        = each.value.address
    user        = each.value.user
    private_key = file(each.value.private_key)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '=== Installing K3S Agent on ${each.key} ==='",

      # Enable kernel modules
      "echo 'Configuring kernel modules...'",
      "cat <<'EOF' | doas tee /etc/modules-load.d/containerd.conf > /dev/null",
      "overlay",
      "br_netfilter",
      "EOF",
      "doas modprobe overlay 2>/dev/null || true",
      "doas modprobe br_netfilter 2>/dev/null || true",

      # Make mount points shared
      "echo 'Configuring mount points...'",
      "doas mount --make-rshared / 2>/dev/null || true",
      "doas rc-update add local default 2>/dev/null || true",
      "cat <<'EOF' | doas tee /etc/local.d/shared-mount.start > /dev/null",
      "#!/bin/sh",
      "mount --make-rshared /",
      "EOF",
      "doas chmod +x /etc/local.d/shared-mount.start",

      # Download K3S install script
      "echo 'Downloading K3S install script...'",
      "curl -sfL https://get.k3s.io -o /tmp/k3s_install.sh",
      "chmod +x /tmp/k3s_install.sh",

      # Wait for server to be ready
      "echo 'Waiting for K3S server to be accessible...'",
      "for i in {1..30}; do nc -zv ${var.server_host.address} 6443 2>&1 && break || sleep 10; done",

      # Install K3S agent
      "echo 'Installing K3S agent ${var.k3s_version}...'",
      "INSTALL_K3S_VERSION='${var.k3s_version}' K3S_TOKEN='${var.k3s_token}' K3S_URL='https://${var.server_host.address}:6443' INSTALL_K3S_EXEC='${local.agent_exec_flags}' doas sh /tmp/k3s_install.sh",

      # Wait for agent to be ready
      "echo 'Waiting for K3S agent to be ready...'",
      "sleep 10",

      "echo '=== K3S Agent installation complete ==='",
    ]
  }

  triggers = {
    version      = var.k3s_version
    token        = md5(var.k3s_token)
    use_cilium   = var.k3s_use_cilium
    server_ready = null_resource.k3s_server.id
    common_setup = var.depends_on_common_setup
  }
}

# Distribute kubeconfig to all nodes
resource "null_resource" "distribute_kubeconfig" {
  for_each   = var.agent_hosts
  depends_on = [null_resource.fetch_kubeconfig, null_resource.k3s_agents]

  connection {
    type        = "ssh"
    host        = each.value.address
    user        = each.value.user
    private_key = file(each.value.private_key)
    timeout     = "2m"
  }

  provisioner "file" {
    source      = local.local_kubeconfig
    destination = "/tmp/k3s.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "doas mkdir -p /etc/rancher/k3s",
      "doas mv /tmp/k3s.yaml ${local.kubeconfig_path}",
      "doas chmod 600 ${local.kubeconfig_path}",
    ]
  }

  triggers = {
    kubeconfig_ready = null_resource.fetch_kubeconfig.id
  }
}

# ===========================
# Cilium Installation (Optional)
# ===========================

resource "null_resource" "cilium" {
  count      = var.k3s_use_cilium ? 1 : 0
  depends_on = [null_resource.k3s_server, null_resource.k3s_agents]

  connection {
    type        = "ssh"
    host        = var.server_host.address
    user        = var.server_host.user
    private_key = file(var.server_host.private_key)
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '=== Installing Cilium ==='",

      # Detect architecture
      "ARCH=$(uname -m)",
      "if [ \"$ARCH\" = \"aarch64\" ]; then ARCH='arm64'; else ARCH='amd64'; fi",

      # Download Cilium CLI
      "echo 'Downloading Cilium CLI ${var.cilium_cli_version}...'",
      "curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${var.cilium_cli_version}/cilium-linux-$${ARCH}.tar.gz{,.sha256sum}",
      "sha256sum --check cilium-linux-$${ARCH}.tar.gz.sha256sum",
      "doas tar xzvfC cilium-linux-$${ARCH}.tar.gz /usr/local/bin",
      "rm cilium-linux-$${ARCH}.tar.gz{,.sha256sum}",

      # Install Cilium
      "echo 'Installing Cilium ${var.cilium_version}...'",
      "KUBECONFIG=${local.kubeconfig_path} doas cilium install --version=${var.cilium_version} --set=ipam.operator.clusterPoolIPv4PodCIDRList='10.42.0.0/16'",

      # Wait for Cilium to be ready
      "echo 'Waiting for Cilium to be ready...'",
      "for i in {1..20}; do KUBECONFIG=${local.kubeconfig_path} doas cilium status && break || sleep 30; done",

      "echo '=== Cilium installation complete ==='",
    ]
  }

  triggers = {
    cilium_version = var.cilium_version
    cluster_ready  = null_resource.k3s_server.id
  }
}

# Wait for cluster to be fully ready
resource "null_resource" "cluster_ready" {
  depends_on = [
    null_resource.k3s_server,
    null_resource.k3s_agents,
    null_resource.distribute_kubeconfig,
    null_resource.cilium
  ]

  connection {
    type        = "ssh"
    host        = var.server_host.address
    user        = var.server_host.user
    private_key = file(var.server_host.private_key)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '=== Verifying cluster health ==='",
      "for i in {1..20}; do doas kubectl get nodes && break || sleep 15; done",
      "doas kubectl get nodes",
      "echo '=== Cluster is ready ==='",
    ]
  }

  triggers = {
    server_ready = null_resource.k3s_server.id
    agents_ready = join(",", [for k, v in null_resource.k3s_agents : v.id])
  }
}
