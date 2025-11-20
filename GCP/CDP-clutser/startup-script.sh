#!/bin/bash
# startup-script for both management and worker nodes
# - installs prerequisites
# - configures /etc/hosts with discovered nodes using GCP metadata server (we will rely on Terraform to supply hostname info via hostnames above if you extend)
# - for management node, attempts to download and run Cloudera Manager installer (requires cloudera_installer_url variable value baked into the metadata if desired)
# NOTE: This script uses placeholders. You must set var.cloudera_installer_url (example: a public gs:// or https URL).

set -xe

ROLE=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/role")
# Install updates and basic packages
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
apt-get -y install openjdk-11-jdk curl wget apt-transport-https gnupg lsb-release unzip

# Set hostname (already set by GCP) and ensure /etc/hosts resolves internal IPs for all nodes:
# Terraform currently doesn't populate metadata with full host list in this sample.
# For production, pass the full hosts/IPs to metadata and populate /etc/hosts here.

# Disable SELinux (not needed on Ubuntu) — keep for RHEL
# Setup swap (optional)
fallocate -l 8G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Common recommended OS settings for Cloudera
sysctl -w vm.swappiness=10
echo "vm.swappiness = 10" >> /etc/sysctl.conf

# Docker is optional depending on services; install if necessary:
# apt-get -y install docker.io
# systemctl enable docker

# Placeholder: install Cloudera Manager agent and server if repository available.
# You MUST provide a Cloudera Manager repo or installer URL. For PoC, you can upload the CM installer .sh to a public GCS URL and set it as cloudera_installer_url.

CLOUDERA_INSTALLER_URL="{{CLOUDERA_INSTALLER_URL_PLACEHOLDER}}"

if [ "$ROLE" == "management" ]; then
  if [ -n "$CLOUDERA_INSTALLER_URL" ] && [ "$CLOUDERA_INSTALLER_URL" != "{{CLOUDERA_INSTALLER_URL_PLACEHOLDER}}" ]; then
    cd /tmp
    echo "Downloading Cloudera Manager installer from ${CLOUDERA_INSTALLER_URL}"
    curl -sSL -o cm-installer.sh "${CLOUDERA_INSTALLER_URL}"
    chmod +x cm-installer.sh

    # Run CM installer - express (embedded DB) or modify for external DB.
    # WARNING: express installs for PoC only.
    if [ "{{USE_EMBEDDED_DB}}" == "true" ]; then
      ./cm-installer.sh --express
    else
      ./cm-installer.sh
    fi
  else
    echo "No Cloudera installer URL provided in metadata; skipping CM installer. Please run manual install on management node."
  fi
else
  # Worker node - the Cloudera Manager Agent will be installed by CM server once you register nodes in the CM UI.
  echo "Worker node bootstrap complete. Wait for Cloudera Manager to install agent packages or install agent manually."
fi

echo "startup-script complete"