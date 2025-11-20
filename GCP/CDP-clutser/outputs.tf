output "management_public_ips" {
  description = "Public IPs of management nodes (Cloudera Manager)"
  value       = [for m in google_compute_instance.management : m.network_interface[0].access_config[0].nat_ip]
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = [for w in google_compute_instance.worker : w.network_interface[0].access_config[0].nat_ip]
}

output "management_internal_ips" {
  description = "Internal IPs of management nodes"
  value       = [for m in google_compute_instance.management : m.network_interface[0].network_ip]
}

output "worker_internal_ips" {
  description = "Internal IPs of worker nodes"
  value       = [for w in google_compute_instance.worker : w.network_interface[0].network_ip]
}