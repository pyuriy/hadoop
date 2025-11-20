# Terraform-based GCP deployment for Cloudera (CDP/CPD) cluster (PoC)

This repository contains Terraform code and a bootstrap startup script to provision GCP networking and VMs for a Cloudera cluster (Cloudera Manager + worker nodes). It creates:
- VPC and subnet
- Firewall rules (SSH + common Cloudera ports)
- Management instance(s) for Cloudera Manager
- Worker instances

Important: Because Cloudera software (Cloudera Manager, parcels, parcels server) is not public, you must supply Cloudera installer URL and any required license or repositories. This Terraform is intended for PoC/testing. For production you must:
- Use hardened images (RHEL/CentOS 7/8 or certified Ubuntu + updates)
- Use external DB for Cloudera Manager (Postgres/MySQL) and configure backups
- Use private networks and firewall rules more restrictive than 0.0.0.0/0
- Use IAM / service accounts with least privilege

Prerequisites
1. GCP project with billing enabled.
2. Enable these APIs:
   - Compute Engine API
   - IAM API
   - Cloud Storage API (if using GCS for storing installer)
3. Terraform v1.0+ installed.
4. A GCP service account with the roles:
   - roles/compute.admin
   - roles/iam.serviceAccountUser
   - roles/storage.admin (only if uploading installer to GCS)
   - roles/compute.networkAdmin
   Alternatively configure gcloud auth application-default login on the machine running terraform.
5. Obtain and host the Cloudera Manager installer:
   - Download Cloudera Manager installer (from Cloudera support portal) and upload to a GCS bucket or HTTP server you control, OR use Cloudera's public download URL if accessible.
   - Make sure the instance(s) can access that URL. For GCS private objects, ensure service account has read access.
6. Prepare an SSH public key to allow access to VMs.

Quick start (PoC using embedded DB)
1. Clone repo locally.
2. Edit variables.tf or create terraform.tfvars with values:
   - project = "my-gcp-project"
   - region / zone as desired
   - ssh_public_key = "ubuntu:ssh-rsa AAAA... user@host"
   - cloudera_installer_url = "https://storage.googleapis.com/my-bucket/cm-installer.sh" (or Cloudera URL)
   - use_embedded_db = true (PoC only)
3. Initialize Terraform:
   terraform init
4. Plan:
   terraform plan -out plan.tfplan
5. Apply:
   terraform apply "plan.tfplan"

What the startup script does
- Installs Java 11 and basic packages.
- Creates a small swap file.
- For ROLE=management node: downloads the Cloudera Manager installer from the URL you provided and runs it in express mode (embedded DB) if enabled.
- For worker nodes: prepared to receive agent installs from Cloudera Manager.

After apply finishes
1. Get the management node public IP from terraform outputs:
   terraform output management_public_ips
2. Visit the Cloudera Manager UI:
   http://<management-ip>:7180
   - Default Cloudera Manager credentials (if using express installer) are typically admin/admin. Confirm with the installer output.
   - If you used the embedded DB express installer, Cloudera Manager will attempt to install required parcels and the agent on that same node.
3. Add hosts in Cloudera Manager:
   - From the CM UI, provide the list of hostnames/internal IPs for all worker nodes. The CM uses SSH (typically) to install agents on nodes — ensure the SSH key and user configured in the CM UI can access nodes.
   - Alternatively, install Cloudera Manager Agent on nodes manually by adding the Cloudera package repository and apt-get installing `cloudera-manager-agent` and pointing the agent to the CM server in /etc/cloudera-scm-agent/config.
4. Upload parcels or configure repository:
   - Add CDH/CDP parcels or configure Cloudera Manager to use the Cloudera repository (requires internet or an internal parcels server).
5. Configure services (HDFS, YARN, Hive, etc.) using the Cloudera Manager wizard and deploy roles to the worker nodes.
6. For production, configure an external database for CM and configure TLS, Kerberos, monitoring and backups.

Files overview
- providers.tf: GCP provider configuration
- variables.tf: Input variables
- main.tf: resources (VPC, firewall, instances)
- startup-script.sh: bootstrap script (executed on each VM at first boot)
- outputs.tf: IP outputs
- README.md: this document

Security & production notes
- Do NOT leave firewall source_ranges = ["0.0.0.0/0"] in production. Limit to admin IP ranges.
- Use external RDBMS for Cloudera Manager (Postgres or MySQL) using high availability.
- Use internal/private networks for inter-node communication; use Cloud NAT if outbound internet is required.
- Use OS images supported by Cloudera and apply the required OS tuning and kernel settings before installing services.
- For large clusters consider using specialized machine types, local SSDs, and tuned disk layouts for HDFS/DataNode.

Troubleshooting tips
- Check instance logs via serial console if startup-script fails.
- SSH to nodes and inspect /var/log/cloud-init-output.log or /var/log/syslog for errors.
- If Cloudera Manager installer fails due to missing packages, download and reference the correct repository per Cloudera docs.

Next steps I can help with
- I can generate a variant that:
  - populates /etc/hosts automatically (passing IPs/hostnames from Terraform to the startup script)
  - creates an external Postgres instance and configures the CM installer to use it
  - installs CM agent package repo via Terraform metadata and ensures agents preinstalled on workers
  - use startup-script templating to inject actual values (cloudera_installer_url, use_embedded_db) into the script before apply
- If you want, tell me whether you prefer embedded DB (PoC) or external DB (production), and whether you want me to template the startup script with proper Terraform templatefile usage to inject variables directly.
