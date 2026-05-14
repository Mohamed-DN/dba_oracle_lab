resource "oci_core_vcn" "oracle_vcn" {
  cidr_block     = var.vcn_cidr_block
  compartment_id = var.compartment_ocid
  display_name   = "Oracle_26ai_VCN"
  dns_label      = "oraclevcn"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oracle_vcn.id
  display_name   = "Oracle_IGW"
}

resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oracle_vcn.id
  display_name   = "Public_Route_Table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_security_list" "oracle_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oracle_vcn.id
  display_name   = "Oracle_Security_List"

  # Egress verso internet
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Ingress SSH
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      max = 22
      min = 22
    }
  }

  # Ingress Oracle Listener 1521
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0" # In prod restringere agli IP del bastion
    tcp_options {
      max = 1521
      min = 1521
    }
  }
}

resource "oci_core_subnet" "public_subnet" {
  cidr_block                 = var.public_subnet_cidr
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.oracle_vcn.id
  display_name               = "Oracle_Public_Subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public_rt.id
  security_list_ids          = [oci_core_security_list.oracle_sl.id]
  prohibit_public_ip_on_vnic = false
}
