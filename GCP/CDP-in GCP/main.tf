# =================================================================
# 1. ПРОВАЙДЕР ТА ЗМІННІ
# =================================================================
provider "google" {
  credentials = file(var.gcp_auth_file)
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# =================================================================
# 2. МЕРЕЖА (VPC & FIREWALL)
# =================================================================
resource "google_compute_network" "hadoop_vpc" {
  name                    = "hadoop-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "hadoop_subnet" {
  name          = "hadoop-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.hadoop_vpc.id
  region        = var.region
}

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
    # 22: SSH, 7180: Cloudera Manager, 8888: Hue, 9870: HDFS, 8088: YARN
    ports    = ["22", "7180", "8888", "9870", "8088"]
  }

  # ТУТ ВІДБУВАЄТЬСЯ МАГІЯ БЕЗПЕКИ:
  source_ranges = ["${var.my_external_ip}/32"]
}

# =================================================================
# 3. ДИСКИ ТА ОБЧИСЛЮВАЛЬНІ РЕСУРСИ
# =================================================================
resource "google_compute_disk" "data_disks" {
  count = length(var.node_names)
  name  = "data-disk-${count.index}"
  type  = "pd-standard"
  size  = 50
  zone  = var.zone
}

resource "google_compute_instance" "hadoop_nodes" {
  count        = length(var.node_names)
  name         = var.node_names[count.index]
  machine_type = var.machine_type
  zone         = var.zone

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_pub_key_path)}"
  }

  boot_disk {
    initialize_params {
      image = "rocky-linux-cloud/rocky-linux-8"
      size  = 50
    }
  }

  attached_disk {
    source      = google_compute_disk.data_disks[count.index].name
    device_name = "data-disk"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.hadoop_subnet.name
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    yum install -y java-1.8.0-openjdk-devel wget net-tools
    systemctl stop firewalld && systemctl disable firewalld
    echo "vm.swappiness = 10" >> /etc/sysctl.conf && sysctl -p
    mkdir -p /data
    mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
    mount -o discard,defaults /dev/sdb /data
    echo "/dev/sdb /data ext4 discard,defaults,nofail 0 2" >> /etc/fstab
  EOT
}

# =================================================================
# 4. АВТОМАТИЗАЦІЯ ДЛЯ ANSIBLE (Генерація hosts.ini)
# =================================================================
resource "local_file" "ansible_inventory" {
  content = templatefile("hosts.tpl", {
    nodes    = google_compute_instance.hadoop_nodes,
    ssh_user = var.ssh_user
  })
  filename = "hosts.ini"
}

# =================================================================
# 5. ВИВІД (OUTPUTS)
# =================================================================
output "cluster_ips" {
  value = {
    for instance in google_compute_instance.hadoop_nodes :
    instance.name => instance.network_interface[0].access_config[0].nat_ip
  }
}
