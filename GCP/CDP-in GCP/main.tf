# 1. Провайдер та змінні
provider "google" {
  project = "your-project-id" # ЗАМІНІТЬ НА ВАШ PROJECT ID
  region  = "us-central1"
  zone    = "us-central1-a"
}

variable "ssh_user" {
  default = "centos"
}

variable "ssh_pub_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "node_names" {
  default = ["master-01", "worker-01", "worker-02"]
}

# 2. Мережева інфраструктура (VPC & Subnet)
resource "google_compute_network" "hadoop_vpc" {
  name                    = "hadoop-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "hadoop_subnet" {
  name          = "hadoop-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.hadoop_vpc.id
}

# 3. Правила Firewall
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
    ports    = ["22", "7180", "8888", "9870", "8088"] # SSH, CM, Hue, HDFS UI, YARN UI
  }
  source_ranges = ["0.0.0.0/0"] # В реальних проєктах обмежте вашою IP
}

# 4. Додаткові диски для даних HDFS (SSD для швидкості)
resource "google_compute_disk" "data_disks" {
  count = length(var.node_names)
  name  = "data-disk-${count.index}"
  type  = "pd-ssd"
  size  = 200
  zone  = "us-central1-a"
}

# 5. Віртуальні машини (Інстанси)
resource "google_compute_instance" "hadoop_nodes" {
  count        = length(var.node_names)
  name         = var.node_names[count.index]
  machine_type = "n2-standard-8" # Рекомендовано для CDP 7
  zone         = "us-central1-a"

  # Додавання вашого SSH ключа в метадані
  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_pub_key_path)}"
  }

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      size  = 100
    }
  }

  attached_disk {
    source = google_compute_disk.data_disks[count.index].name
    device_name = "data-disk"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.hadoop_subnet.name
    access_config {
      # Надає зовнішню IP адресу
    }
  }

  # Початкове налаштування ОС
  metadata_startup_script = <<-EOT
    #!/bin/bash
    yum install -y java-1.8.0-openjdk-devel wget net-tools
    systemctl stop firewalld
    systemctl disable firewalld
    echo "vm.swappiness = 10" >> /etc/sysctl.conf
    sysctl -p
    # Форматування та монтування додаткового диска
    mkdir -p /data
    mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
    mount -o discard,defaults /dev/sdb /data
    echo "/dev/sdb /data ext4 discard,defaults,nofail 0 2" >> /etc/fstab
  EOT
}

# 6. Вивід результатів (Outputs)
output "instance_ips" {
  value = {
    for instance in google_compute_instance.hadoop_nodes :
    instance.name => instance.network_interface[0].access_config[0].nat_ip
  }
}
