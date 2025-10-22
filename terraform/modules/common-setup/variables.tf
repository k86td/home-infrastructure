variable "hosts" {
  description = "Map of hosts to configure with common setup"
  type = map(object({
    address     = string
    user        = string
    private_key = string
  }))
}

variable "common_users" {
  description = "List of users to create on all hosts"
  type = list(object({
    name        = string
    ssh_keys    = list(string)
    groups      = optional(list(string), [])
    create_home = optional(bool, true)
  }))
  default = []
}

variable "alpine_packages" {
  description = "List of Alpine packages to install"
  type        = list(string)
  default     = ["tar"]
}

variable "enable_community_repo" {
  description = "Enable Alpine community repository"
  type        = bool
  default     = true
}

variable "ssh_disable_root_login" {
  description = "Disable root SSH login"
  type        = bool
  default     = true
}

variable "doas_config" {
  description = "doas configuration content"
  type        = string
  default     = "permit persist :wheel\n"
}

variable "motd_template" {
  description = "Message of the day template"
  type        = string
  default     = ""
}
