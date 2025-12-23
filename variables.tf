variable "tenancy_ocid" {
  description = "OCID of your tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of your user"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of your API key"
  type        = string
}

variable "private_key_path" {
  description = "Path to your private API key"
  type        = string
}

variable "region" {
  description = "Oracle Cloud region"
  type        = string
  default     = "eu-amsterdam-1" # Change to your preferred region
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "ubuntu_password" {
  description = "Password for the ubuntu user"
  type        = string
  sensitive   = true
}

variable "socks5_port" {
  description = "Port for the SOCKS5 proxy"
  type        = number
  default     = 1080
}
