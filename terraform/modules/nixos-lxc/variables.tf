variable "hostname" {
  type        = string
  description = "Container hostname"
}

variable "node_name" {
  type        = string
  description = "Proxmox node to create on"
}

variable "vm_id" {
  type        = number
  description = "Proxmox VMID (null for auto-assign)"
  default     = null
}

variable "cores" {
  type    = number
  default = 2
}

variable "cpu_units" {
  type    = number
  default = null
}

variable "memory" {
  type    = number
  default = 2048
}

variable "swap" {
  type    = number
  default = 512
}

variable "disk_size" {
  type    = number
  default = 8
}

variable "ip" {
  type        = string
  description = "IP address in CIDR notation (e.g. 192.168.1.50/24) or 'dhcp'"
}

variable "gateway" {
  type    = string
  default = "192.168.1.1"
}


variable "unprivileged" {
  type    = bool
  default = true
}

variable "start_on_boot" {
  type    = bool
  default = true
}

variable "template_file_id" {
  type    = string
  default = "local:vztmpl/nixos-26.11-base_amd64.tar.xz"
}

variable "node_ip" {
  type        = string
  default     = null
  description = "IP of the Proxmox node, needed to SSH in for devices and bind_mounts"
}

variable "devices" {
  type = list(object({
    path = string
    gid  = optional(number)
  }))
  default     = []
  description = "Host devices to pass through, with the gid that owns them inside the container"
}

variable "bind_mounts" {
  type        = map(string)
  default     = {}
  description = "Host paths to bind-mount, keyed by their path inside the container"
}

variable "mac_address" {
  type        = string
  default     = null
  description = "MAC address for the network interface (preserves DHCP reservations)"
}

variable "extra_networks" {
  type = list(object({
    vlan_id     = number
    mac_address = string
    ip          = string
  }))
  default     = []
  description = "Extra interfaces on tagged VLANs, as eth1 onwards. Static IPs with no gateway, so eth0 keeps the default route."
}
