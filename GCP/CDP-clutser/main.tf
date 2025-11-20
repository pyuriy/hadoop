locals {
  mgmt_prefix   = "cm"
  worker_prefix = "worker"
}

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.vpc.id
  region        = var.region
}

resource "google_compute_firewall" "allow_ssh_http_cdp" {
  name    = "${var.network_name}-allow-ssh-cdp"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "7180", "7183", "7182", "50070", "9870", "8088", "8042", "9000", "50075"]
  }

  source_ranges = ["0.0.0.0/0"] # restrict for production
  description   = "Allow SSH and common CDP ports (restrict in production)"
}

# Create management instances (Cloudera Manager node(s))
resource "google_compute_instance" "management" {
  count        = var.management_count
  name         = "${local.mgmt_prefix}-${count.index}"
  machine_type = var.cm_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image  = "${var.boot_image_project}/${var.boot_image_family}"
      size   = var.boot_disk_size_gb
      type   = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.name
    access_config {}
  }

  metadata = {
    ssh-keys        = var.ssh_public_key
    startup-script  = file("startup-script.sh")
    all_nodes_count = tostring(var.management_count + var.worker_count)
    role            = "management"
  }

  tags = ["cdp"]
}

# Create worker (data) instances
resource "google_compute_instance" "worker" {
  count        = var.worker_count
  name         = "${local.worker_prefix}-${count.index}"
  machine_type = var.worker_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image  = "${var.boot_image_project}/${var.boot_image_family}"
      size   = var.boot_disk_size_gb
      type   = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.name
    access_config {}
  }

  metadata = {
    ssh-keys       = var.ssh_public_key
    startup-script = file("startup-script.sh")
    role           = "worker"
  }

  tags = ["cdp"]
}

# local-exec to generate /etc/hosts-like mapping so startup script can write hosts
data "google_compute_instance" "all_instances" {
  # depends on instances to exist
  depends_on = [google_compute_instance.management, google_compute_instance.worker]
  # placeholder: we will reference each instance in output below
  count = 0
}