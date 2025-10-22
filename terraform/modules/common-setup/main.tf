# Common Setup Module
# Replicates k86td.common Ansible role functionality

resource "null_resource" "common_setup" {
  for_each = var.hosts

  connection {
    type        = "ssh"
    host        = each.value.address
    user        = each.value.user
    private_key = file(each.value.private_key)
    timeout     = "2m"
  }

  # User Management and System Configuration
  provisioner "remote-exec" {
    inline = [
      "set -e",  # Exit on error
      "echo '=== Common Setup for ${each.key} ==='",

      # Create users with proper groups
      <<-EOT
      %{for user in var.common_users~}
      echo "Creating user ${user.name}..."
      if ! id ${user.name} &>/dev/null; then
        doas adduser -D ${user.name} || echo "User ${user.name} may already exist"
      fi
      %{if length(user.groups) > 0~}
      %{for group in user.groups~}
      doas addgroup ${user.name} ${group} 2>/dev/null || true
      %{endfor~}
      %{endif~}

      # Set up SSH directory
      doas mkdir -p /home/${user.name}/.ssh
      doas chmod 700 /home/${user.name}/.ssh

      # Fetch SSH keys from GitHub if URL is provided, otherwise use provided keys
      %{if length(user.ssh_keys) > 0~}
      %{for key in user.ssh_keys~}
      %{if can(regex("^https://", key))~}
      echo "Fetching SSH keys from ${key}..."
      doas wget -qO- "${key}" >> /home/${user.name}/.ssh/authorized_keys 2>/dev/null || echo "Warning: Could not fetch keys from ${key}"
      %{else~}
      echo "${key}" | doas tee -a /home/${user.name}/.ssh/authorized_keys > /dev/null
      %{endif~}
      %{endfor~}
      %{endif~}

      doas chmod 600 /home/${user.name}/.ssh/authorized_keys
      doas chown -R ${user.name}:${user.name} /home/${user.name}/.ssh
      %{endfor~}
      EOT
      ,

      # Configure doas
      "echo 'Configuring doas...'",
      "echo '${var.doas_config}' | doas tee /etc/doas.conf > /dev/null",
      "doas chmod 644 /etc/doas.conf",

      # Enable Alpine community repository
      var.enable_community_repo ? <<-EOT
      echo "Enabling Alpine community repository..."
      ALPINE_VERSION=$(cat /etc/alpine-release | cut -d'.' -f1,2)
      if ! grep -q "community" /etc/apk/repositories; then
        echo "http://dl-cdn.alpinelinux.org/alpine/v$${ALPINE_VERSION}/community" | doas tee -a /etc/apk/repositories > /dev/null
      fi
      EOT
      : "echo 'Skipping community repository setup'",

      # Update and upgrade packages
      "echo 'Updating package cache...'",
      "doas apk update",
      "doas apk upgrade",

      # Install packages
      length(var.alpine_packages) > 0 ? "echo 'Installing packages: ${join(" ", var.alpine_packages)}...'" : "echo 'No packages to install'",
      length(var.alpine_packages) > 0 ? "doas apk add ${join(" ", var.alpine_packages)}" : "true",

      # SSH hardening
      var.ssh_disable_root_login ? <<-EOT
      echo "Hardening SSH configuration..."
      if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
        doas sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
      fi
      EOT
      : "echo 'Skipping SSH hardening'",

      # Set MOTD
      var.motd_template != "" ? <<-EOT
      echo "Setting MOTD..."
      cat <<'MOTD_EOF' | doas tee /etc/motd > /dev/null
${var.motd_template}

This is ${each.key}
MOTD_EOF
      EOT
      : "echo 'Skipping MOTD setup'",

      "echo '=== Common setup completed for ${each.key} ==='",
    ]
  }

  # Trigger re-run when configuration changes
  triggers = {
    users_hash    = md5(jsonencode(var.common_users))
    packages_hash = md5(jsonencode(var.alpine_packages))
    doas_config   = md5(var.doas_config)
    motd          = md5(var.motd_template)
  }
}
