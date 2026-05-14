variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {
  default = "eu-frankfurt-1"
}

variable "compartment_ocid" {}

variable "vcn_cidr_block" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "ssh_public_key" {
  description = "Public SSH key per l'accesso alle istanze Oracle"
}
