provider "google" {
  project = var.project
  region  = var.region
}

// MongoDB Instances
resource "google_compute_instance" "mongo" {
  count        = 3
  name         = "mongo-test${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["mongo"]
  boot_disk {
    initialize_params {
      image = var.disk_image
    }
  }
  metadata = {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
  network_interface {
    network = "default"
    access_config {}
  }
  connection {
    type        = "ssh"
    host        = self.network_interface[0].access_config[0].nat_ip
    user        = "appuser"
    agent       = false
    private_key = file(var.private_key_path)
  }
}

// Firewall rules
resource "google_compute_firewall" "firewall_ssh" {
  name    = "default-allow-ssh"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = [var.source_ranges]
}

// Generate ansible hosts file
resource "null_resource" "ansible-provision" {
  depends_on = ["google_compute_instance.mongo[0]", "google_compute_instance.mongo[1]", "google_compute_instance.mongo[2]"]

  provisioner "local-exec" {
    command = "echo [mongo_master] > hosts"
  }

  provisioner "local-exec" {
    command = "echo '${google_compute_instance.mongo[0].name} ansible_host=${google_compute_instance.mongo[0].network_interface.0.access_config.0.nat_ip}' >> hosts"
  }

   provisioner "local-exec" {
    command = "echo [mongo_replicas] >> hosts"
  }

  provisioner "local-exec" {
    command = "echo '${google_compute_instance.mongo[1].name} ansible_host=${google_compute_instance.mongo[1].network_interface.0.access_config.0.nat_ip}' >> hosts"
  }

  provisioner "local-exec" {
    command = "echo '${google_compute_instance.mongo[2].name} ansible_host=${google_compute_instance.mongo[2].network_interface.0.access_config.0.nat_ip}' >> hosts"
  }

  provisioner "local-exec" {
    command = "echo [mongo:children] >> hosts"
  }

  provisioner "local-exec" {
    command = "echo mongo_master >> hosts"
  }

  provisioner "local-exec" {
    command = "echo mongo_replicas >> hosts"
  }

  provisioner "local-exec" {
    command = "cp hosts ../ansible"
  }
}
