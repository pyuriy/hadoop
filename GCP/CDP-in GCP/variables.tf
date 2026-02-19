variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
}

variable "gcp_auth_file" {
  type        = string
  description = "Шлях до файлу JSON з ключами сервісного акаунта"
}

variable "region" {
  default = "northamerica-northeast2"
}

variable "zone" {
  default = "northamerica-northeast2-c"
}

variable "ssh_user" {
  description = "The user that will be created on the VMs"
  default     = "yvp"
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
  default     = "e2-standard-4"
}

variable "my_external_ip" {
  type        = string
  description = "My local external IP address for security"
}
