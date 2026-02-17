variable "ssh_pub_key_path" {
  description = "Path to the SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_user" {
  description = "SSH user to create"
  default     = "centos"
}
