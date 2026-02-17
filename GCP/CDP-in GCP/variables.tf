variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-a"
}

variable "ssh_user" {
  description = "The user that will be created on the VMs"
  default     = "centos"
}

variable "ssh_pub_key_path" {
  description = "Local path to your public SSH key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "node_names" {
  type    = list(string)
  default = ["master-01", "worker-01", "worker-02"]
}

variable "machine_type" {
  description = "Size of the VMs"
  default     = "n2-standard-8"
}
