Here is a comprehensive **README.md** file that combines the Infrastructure (Terraform) and Configuration (Ansible) steps into a single professional guide.

---

# Cloudera CDP 7 Hadoop Cluster on Google Cloud

This project provides a complete automated workflow to deploy a **3-node Cloudera Data Platform (CDP) 7 cluster** on Google Cloud Platform (GCP). It uses **Terraform** for infrastructure provisioning and **Ansible** for software configuration.

## 🏗️ Architecture Overview

* **Provider:** Google Cloud Platform (GCP)
* **Nodes:** 3 x `n2-standard-8` (1 Master/CM Server, 2 Workers)
* **OS:** CentOS 7 (Optimized for Cloudera)
* **Network:** Custom VPC with specific firewall rules for Hadoop internal communication and UI access.
* **Storage:** 100GB Boot Disk + 200GB SSD Persistent Disk per node for HDFS.

---

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

1. [Terraform]() (v1.0+)
2. [Ansible]()
3. [Google Cloud SDK (gcloud)]()
4. An active GCP Project with Billing enabled.

---

## 🚀 Step 1: Infrastructure Provisioning (Terraform)

1. **Initialize Terraform:**
```bash
terraform init

```


2. **Plan the deployment:**
Check the resources that will be created:
```bash
terraform plan -var="project=your-project-id"

```


3. **Apply the configuration:**
```bash
terraform apply -var="project=your-project-id"

```


*Note: After completion, Terraform will output the external IP addresses of your instances. Save these for the next step.*

---

## 🛠️ Step 2: Software Configuration (Ansible)

Once the VMs are running, we need to install Cloudera Manager and prepare the OS.

1. **Configure Inventory:**
Edit the `hosts.ini` file. Replace the placeholder IPs with the ones from Terraform:
```ini
[all_nodes]
master-01 ansible_host=34.x.x.x
worker-01 ansible_host=34.x.x.y
worker-02 ansible_host=34.x.x.z

[cm_server]
master-01 ansible_host=34.x.x.x

[vars]
ansible_user=centos
ansible_ssh_private_key_file=~/.ssh/id_rsa

```


2. **Verify Connectivity:**
```bash
ansible all -i hosts.ini -m ping

```


3. **Run the Playbook:**
This will disable SELinux/THP, install Java 8, and set up Cloudera Manager:
```bash
ansible-playbook -i hosts.ini deploy-cm.yml

```



---

## 🖥️ Step 3: Accessing Cloudera Manager

1. Wait about 2-3 minutes for the Cloudera Manager service to start.
2. Open your browser and navigate to:
`http://<MASTER_PUBLIC_IP>:7180`
3. **Default Credentials:**
* **Username:** `admin`
* **Password:** `admin`



---

## ⚠️ Important Notes

* **Cost:** Running 3 `n2-standard-8` nodes costs approximately **$15-20/day**.
* **Cleanup:** To avoid unexpected charges, destroy the infrastructure when finished:
```bash
terraform destroy

```


* **Security:** The firewall rules in this template allow access from `0.0.0.0/0`. For production, restrict this to your specific IP address.

---
