output "vm_inventory" {
  description = "VM metadata to feed dynamic inventory consumers (Ansible/AWX)."
  value       = local.vm_metadata
}

output "vm_hosts" {
  description = "Hostnames created by Terraform."
  value       = keys(local.vm_metadata.hosts)
}

output "metadata_file_path" {
  description = "Path of generated VM metadata JSON file."
  value       = local_file.terraform_metadata.filename
}

output "checkmk_profile" {
  description = "Generated Checkmk naming profile for EDC integration."
  value       = local.checkmk_profile
}

output "checkmk_ansible_vars_path" {
  description = "Path of generated Ansible vars file for Checkmk setup."
  value       = local_file.checkmk_ansible_vars.filename
}
