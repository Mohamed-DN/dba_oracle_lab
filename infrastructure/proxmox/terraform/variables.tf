variable "environment" {
  description = "Environment name used for resource naming."
  type        = string
  default     = "lab"
}

variable "pm_api_url" {
  description = "Proxmox API URL, e.g. https://pve.local:8006/api2/json"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token id, e.g. terraform@pve!token"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Allow insecure TLS to Proxmox API"
  type        = bool
  default     = false
}

variable "target_node" {
  description = "Proxmox node where VMs are created"
  type        = string
}

variable "cloud_init_template" {
  description = "Cloud-init template name available on Proxmox"
  type        = string
}

variable "network_bridge" {
  description = "Linux bridge used by VM NIC"
  type        = string
  default     = "vmbr0"
}

variable "storage_pool" {
  description = "Storage pool used for VM disk"
  type        = string
  default     = "local-lvm"
}

variable "vm_cores" {
  description = "vCPU per VM"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory per VM in MB"
  type        = number
  default     = 4096
}

variable "vm_disk_size" {
  description = "Disk size per VM"
  type        = string
  default     = "40G"
}

variable "vm_gateway" {
  description = "Default gateway"
  type        = string
}

variable "vm_cidr" {
  description = "CIDR prefix for VM IPs"
  type        = number
  default     = 24
}

variable "vm_dns" {
  description = "DNS server for cloud-init"
  type        = string
}

variable "ci_user" {
  description = "Cloud-init admin username"
  type        = string
  default     = "dbaadmin"
}

variable "ci_ssh_public_key" {
  description = "SSH public key for cloud-init user"
  type        = string
}

variable "vms" {
  description = "VM map with role and IP"
  type = map(object({
    ip   = string
    role = string
  }))
  default = {
    vm01 = {
      ip   = "192.168.56.201"
      role = "control-plane"
    }
    vm02 = {
      ip   = "192.168.56.202"
      role = "worker"
    }
    vm03 = {
      ip   = "192.168.56.203"
      role = "worker"
    }
  }
}

variable "checkmk_site_id" {
  description = "Checkmk site ID for the environment."
  type        = string
  default     = ""
}

variable "checkmk_folder_root" {
  description = "Root folder for Checkmk host organization."
  type        = string
  default     = "/EDC"
}

variable "checkmk_host_prefix" {
  description = "Prefix used for Checkmk host naming."
  type        = string
  default     = "edc"
}

variable "automation_group_vars_relpath" {
  description = "Relative path (from this module) to automation/group_vars directory."
  type        = string
  default     = "../../../automation/group_vars"
}
