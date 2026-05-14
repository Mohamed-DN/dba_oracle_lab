data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Ricerca dell'immagine Oracle Linux 8
data "oci_core_images" "ol8" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "oracle_26ai_node" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "oracle-26ai-primary"
  shape               = "VM.Standard.A1.Flex" # Istanza ARM Always Free compatibile con 26ai (se OS Oracle Linux 8)

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    display_name     = "primary-vnic"
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ol8.images[0].id
    boot_volume_size_in_gbs = 100
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

output "oracle_26ai_public_ip" {
  value = oci_core_instance.oracle_26ai_node.public_ip
}
