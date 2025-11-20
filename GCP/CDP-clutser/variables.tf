variable "project" {
  description = "GCP project id"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "sa_key_file" {
  description = "Path to service account JSON key on your workstation used by terraform (locally). Terraform will use ADC if empty."
  type        = string
  default     = ""
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "cdp-network"
}

variable "subnet_cidr" {
  description = "Subnet CIDR"
  type        = string
  default     = "10.10.0.0/16"
}

variable "management_count" {
  description = "Number of management (Cloudera Manager) nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker/data nodes"
  type        = number
  default     = 3
}

variable "cm_machine_type" {
  description = "Machine type for CM/management nodes"
  type        = string
  default     = "n2-standard-8"
}

variable "worker_machine_type" {
  description = "Machine type for worker nodes"
  type        = string
  default     = "n2-standard-8"
}

variable "boot_image_project" {
  description = "GCP image project"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "boot_image_family" {
  description = "GCP image family"
  type        = string
  default     = "ubuntu-2004-lts"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size GB"
  type        = number
  default     = 100
}

variable "ssh_public_key" {
  description = "SSH public key content for admin access (format: 'username:ssh-rsa AAA....')"
  type        = string
  default     = ""
}

variable "cloudera_installer_url" {
  description = "HTTP(S) URL to Cloudera Manager installer .sh (you must supply - example: a GCS public URL or Cloudera download URL)."
  type        = string
  default     = ""
}

variable "use_embedded_db" {
  description = "Whether to run CM installer with embedded Postgres (true for PoC). For production, use an external DB."
  type        = bool
  default     = true
}