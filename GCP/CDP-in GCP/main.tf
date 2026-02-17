provider "google" {
  project = "your-project-id"
  region  = "us-central1"
  zone    = "us-central1-a"
}

# 1. VPC Network
resource "google_compute_network" "hadoop_vpc" {
  name                    = "hadoop-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "hadoop_subnet" {
  name          = "hadoop-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.hadoop_vpc.id
}

# 2. Firewall rules
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-hadoop"
  network = google_compute_network.hadoop_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  source_ranges = ["10.0.1.0/24"]
}

resource "google_compute_firewall" "allow_external" {
  name    = "allow-external-ui"
  network = google_compute_network.hadoop_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "7180", "8888"] # SSH, Cloudera Manager, Hue
  }
  source_ranges = ["0.0.0.0/0"] # В реальних проєктах обмежте своєю IP
}

# 3. Instance Template / Nodes
variable "node_names" {
  default = ["master-01", "worker-01", "worker-02"]
}

resource "google_compute_instance" "hadoop_nodes" {
  count        = length(var.node_names)
  name         = var.node_names[count.index]
  machine_type = "n2-standard-8" # CDP потребує багато RAM

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7" # Класика для Cloudera
      size  = 100
    }
  }

  # Додатковий диск для даних HDFS
  attached_disk {
    source = google_compute_disk.data_disks[count.index].name
  }

  network_interface {
    subnetwork = google_compute_subnetwork.hadoop_subnet.name
    access_config {} # Надає зовнішню IP
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    yum install -y java-1.8.0-openjdk-devel wget
    systemctl stop firewalld
    systemctl disable firewalld
    echo "vm.swappiness = 10" >> /etc/sysctl.conf
    sysctl -p
  EOT
}

resource "google_compute_disk" "data_disks" {
  count = 3
  name  = "data-disk-${count.index}"
  type  = "pd-ssd"
  size  = 200
  zone  = "us-central1-a"
}
