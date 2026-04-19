resource "proxmox_vm_qemu" "lab" {
  for_each    = var.vms
  name        = "${var.environment}-${each.key}"
  target_node = var.target_node
  clone       = var.cloud_init_template
  full_clone  = true

  cores   = var.vm_cores
  sockets = 1
  memory  = var.vm_memory
  agent   = 1

  os_type    = "cloud-init"
  ciuser     = var.ci_user
  sshkeys    = var.ci_ssh_public_key
  ipconfig0  = "ip=${each.value.ip}/${var.vm_cidr},gw=${var.vm_gateway}"
  nameserver = var.vm_dns

  network {
    model  = "virtio"
    bridge = var.network_bridge
  }

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.storage_pool
    size    = var.vm_disk_size
    format  = "raw"
  }
}

locals {
  vm_metadata = {
    environment  = var.environment
    generated_at = timestamp()
    hosts = {
      for vm_name, vm in var.vms :
      "${var.environment}-${vm_name}" => {
        ip   = vm.ip
        role = vm.role
      }
    }
  }
}

resource "local_file" "terraform_metadata" {
  filename = "${path.module}/terraform_metadata.json"
  content  = jsonencode(local.vm_metadata)
}
