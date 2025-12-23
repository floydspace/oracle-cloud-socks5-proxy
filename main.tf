terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# Get availability domain
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Get Ubuntu image
data "oci_core_images" "ubuntu" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Create VCN
resource "oci_core_vcn" "socks5_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.tenancy_ocid
  display_name   = "socks5-vcn"
  dns_label      = "socks5vcn"
}

# Create Internet Gateway
resource "oci_core_internet_gateway" "socks5_ig" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.socks5_vcn.id
  display_name   = "socks5-ig"
}

# Create Route Table
resource "oci_core_route_table" "socks5_rt" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.socks5_vcn.id
  display_name   = "socks5-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.socks5_ig.id
  }
}

# Create Security List
resource "oci_core_security_list" "socks5_sl" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.socks5_vcn.id
  display_name   = "socks5-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH on port 22
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # SSH on port 2222 (alternative)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"

    tcp_options {
      min = 2222
      max = 2222
    }
  }

  # SOCKS5 proxy port
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"

    tcp_options {
      min = var.socks5_port
      max = var.socks5_port
    }
  }
}

# Create Subnet
resource "oci_core_subnet" "socks5_subnet" {
  cidr_block        = "10.0.1.0/24"
  compartment_id    = var.tenancy_ocid
  vcn_id            = oci_core_vcn.socks5_vcn.id
  display_name      = "socks5-subnet"
  dns_label         = "socks5subnet"
  route_table_id    = oci_core_route_table.socks5_rt.id
  security_list_ids = [oci_core_security_list.socks5_sl.id]
}



# Create Instance
resource "oci_core_instance" "socks5_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.tenancy_ocid
  display_name        = "socks5-proxy"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.socks5_subnet.id
    display_name     = "socks5-vnic"
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64gzip(templatefile("${path.module}/cloud-init.tpl", {
      ubuntu_password = var.ubuntu_password
      socks5_port     = var.socks5_port
    }))
  }
}

output "instance_public_ip" {
  value = oci_core_instance.socks5_instance.public_ip
}

output "socks5_connection" {
  value = "socks5://${oci_core_instance.socks5_instance.public_ip}:${var.socks5_port}"
}
