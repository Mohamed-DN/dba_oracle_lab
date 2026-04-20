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
  checkmk_site_effective = var.checkmk_site_id != "" ? var.checkmk_site_id : "edc_${var.environment}"
  checkmk_host_map = {
    for vm_name, vm in var.vms :
    "${var.checkmk_host_prefix}-${var.environment}-${vm_name}" => {
      ip   = vm.ip
      role = vm.role
      tags = ["edc", var.environment, vm.role]
    }
  }
  checkmk_profile = {
    environment      = var.environment
    site_id          = local.checkmk_site_effective
    folder_path      = "${var.checkmk_folder_root}/${upper(var.environment)}/ORACLE"
    host_name_prefix = "${var.checkmk_host_prefix}-${var.environment}"
    hosts            = local.checkmk_host_map
  }
  checkmk_ansible_output_dir = var.checkmk_ansible_vars_output_path != "" ? var.checkmk_ansible_vars_output_path : abspath("${path.module}/../../../automation/group_vars")

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

resource "local_file" "checkmk_ansible_vars" {
  filename = "${local.checkmk_ansible_output_dir}/checkmk_generated.yml"
  content = yamlencode({
    checkmk_site_id     = local.checkmk_profile.site_id
    checkmk_folder_path = local.checkmk_profile.folder_path
    checkmk_host_prefix = local.checkmk_profile.host_name_prefix
    checkmk_hosts       = local.checkmk_profile.hosts
  })
}
