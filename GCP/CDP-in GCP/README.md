# Cloudera Manager Deployment on GCP

This guide documents the complete process of deploying Cloudera Manager and setting up a Cloudera Data Platform (CDP) cluster on Google Cloud Platform (GCP).

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Infrastructure Setup](#infrastructure-setup)
- [Cloudera Manager Installation](#cloudera-manager-installation)
- [Configuration Files](#configuration-files)
- [Deployment Steps](#deployment-steps)
- [Troubleshooting](#troubleshooting)
- [Post-Installation](#post-installation)

## Architecture Overview

### Cluster Topology
- **Master Node**: `master-01` - Hosts Cloudera Manager Server and PostgreSQL database
- **Worker Nodes**: `worker-01`, `worker-02` - Compute and storage nodes
- **OS**: Rocky Linux 8 / RHEL 8
- **Cloudera Manager Version**: 7.4.4

### Components
- Cloudera Manager Server (on master node)
- Cloudera Manager Agents (on all nodes)
- PostgreSQL 10+ (database for Cloudera Manager metadata)
- Java 8 (OpenJDK)

## Prerequisites

### Local Requirements
- Terraform (for infrastructure provisioning)
- Ansible 2.9+
- SSH access configured to GCP instances
- GCP credentials and service account

### GCP Resources
- VM instances (1 master + 2 workers minimum)
- Firewall rules allowing:
  - SSH (port 22)
  - Cloudera Manager UI (port 7180)
  - Inter-node communication
- Sufficient CPU, memory, and disk according to Cloudera requirements

### Access Requirements
- Cloudera repository credentials (username/password)
- SSH key pair for Ansible automation

## Infrastructure Setup

### 1. GCP Service Account
Create a service account with appropriate permissions:
```bash
# Service account JSON key file
gcp-cdp-139ca.json
```

### 2. Terraform Provisioning
Use Terraform to provision the infrastructure:
```bash
terraform init
terraform plan
terraform apply
```

### 3. Inventory Configuration
Update `hosts.ini` with your instance IPs:
```ini
[all_nodes]
master-01 ansible_host=<MASTER_IP>
worker-01 ansible_host=<WORKER1_IP>
worker-02 ansible_host=<WORKER2_IP>

[cm_server]
master-01 ansible_host=<MASTER_IP>

[all_nodes:vars]
ansible_user=yvp
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

## Cloudera Manager Installation

### Installation Process Overview
The installation is automated using Ansible playbook (`deploy-cm.yml`) which performs the following tasks:

#### Phase 1: Prepare All Nodes
1. **Disable SELinux** - Required for Cloudera compatibility
2. **Disable Transparent Huge Pages** - Performance optimization
3. **Install Java 8** - Required runtime for Cloudera services
4. **Configure Cloudera Repository** - Uses local `cloudera-manager.repo` file
5. **Install Cloudera Manager Agent** - On all nodes for cluster management

#### Phase 2: Setup Master Node
1. **Install Cloudera Manager Server** - Central management server
2. **Install PostgreSQL** - Database for metadata storage
3. **Configure PostgreSQL Authentication** - Setup proper access controls
4. **Create Database and User** - Dedicated database for Cloudera Manager
5. **Initialize Database Schema** - Prepare tables and structures
6. **Start Services** - Launch Cloudera Manager Server

## Configuration Files

### 1. `cloudera-manager.repo`
Repository configuration with Cloudera archive credentials:
```ini
[cloudera-manager]
name=Cloudera Manager 7.4.4
baseurl=https://archive.cloudera.com/cm7/7.4.4/redhat8/yum/
gpgkey=https://archive.cloudera.com/cm7/7.4.4/redhat8/yum/RPM-GPG-KEY-cloudera
username=changeme
password=changeme
gpgcheck=1
enabled=1
```

**Important**: Replace `username` and `password` with your Cloudera credentials.

### 2. `deploy-cm.yml`
Main Ansible playbook for deployment. Key sections:
- Node preparation tasks
- Repository configuration
- Agent installation
- Server and database setup
- Service initialization

### 3. `hosts.ini`
Ansible inventory file defining cluster topology and connection parameters.

## Deployment Steps

### Step 1: Prepare Configuration Files
```bash
cd /home/yvp/terraform/cloudera/cdp-test/cdp

# Update cloudera-manager.repo with your credentials
vim cloudera-manager.repo

# Verify hosts.ini has correct IP addresses
cat hosts.ini
```

### Step 2: Test Connectivity
```bash
# Test SSH connectivity to all nodes
ansible -i hosts.ini all_nodes -m ping
```

### Step 3: Run Deployment Playbook
```bash
# Deploy Cloudera Manager
ansible-playbook -i hosts.ini deploy-cm.yml
```

### Step 4: Monitor Installation
The playbook will:
- Install packages on all nodes (~5-10 minutes)
- Configure PostgreSQL (~2-3 minutes)
- Initialize Cloudera Manager Server (~2-5 minutes)
- Wait for Cloudera Manager UI to be available

### Step 5: Access Cloudera Manager
```bash
# Check if Cloudera Manager is running
ansible -i hosts.ini cm_server -m shell -a "systemctl status cloudera-scm-server" -b

# Access the web UI
http://<MASTER_IP>:7180

# Default credentials:
# Username: admin
# Password: admin
```

## Troubleshooting

### PostgreSQL Authentication Issues

**Problem**: `FATAL: Ident authentication failed for user "scm"`

**Solution**: The playbook automatically configures PostgreSQL with:
- **Peer authentication** for `postgres` user (Unix socket)
- **MD5 authentication** for `scm` user (password-based)

Check configuration:
```bash
# On master node
sudo cat /var/lib/pgsql/data/pg_hba.conf
sudo systemctl status postgresql
```

### Database Connection Test
```bash
# Test database connectivity
PGPASSWORD='scm_password' psql -h localhost -U scm -d scm -c "SELECT 1;"
```

### Cloudera Manager Server Logs
```bash
# On master node
sudo tail -f /var/log/cloudera-scm-server/cloudera-scm-server.log
```

### PostgreSQL Logs
```bash
# On master node
sudo tail -f /var/lib/pgsql/data/log/postgresql-*.log
# or
sudo journalctl -u postgresql -f
```

### Agent Connection Issues
```bash
# Check agent status on worker nodes
sudo systemctl status cloudera-scm-agent

# Check agent logs
sudo tail -f /var/log/cloudera-scm-agent/cloudera-scm-agent.log
```

### Common Issues and Fixes

#### Issue: Playbook Hangs on Database Creation
**Cause**: PostgreSQL authentication misconfiguration

**Fix**: Restart PostgreSQL to apply new configuration:
```bash
ansible -i hosts.ini cm_server -m systemd -a "name=postgresql state=restarted" -b
```

#### Issue: Cloudera Manager Server Won't Start
**Cause**: Database not properly initialized

**Fix**: 
```bash
# On master node
sudo /opt/cloudera/cm/schema/scm_prepare_database.sh postgresql scm scm scm_password -h localhost
sudo systemctl restart cloudera-scm-server
```

#### Issue: Repository Access Denied
**Cause**: Invalid Cloudera credentials

**Fix**: Update `cloudera-manager.repo` with valid credentials and refresh:
```bash
sudo yum clean all
sudo yum makecache
```

## Post-Installation

### 1. Configure Cluster in Cloudera Manager UI

1. **Access UI**: Navigate to `http://<MASTER_IP>:7180`
2. **Login**: Use default credentials (admin/admin)
3. **Add Cluster**: Follow the wizard to:
   - Specify hosts (all nodes)
   - Select CDH/CDP Runtime version
   - Install parcels
   - Configure services (HDFS, YARN, etc.)

### 2. Security Hardening

#### Change Default Passwords
- Cloudera Manager admin password
- Database passwords
- Service user passwords

#### Enable TLS/SSL
Configure TLS for:
- Cloudera Manager Server
- PostgreSQL connections
- Inter-service communication

#### Configure Kerberos (Optional)
For production environments, enable Kerberos authentication.

### 3. Performance Tuning

#### Disable Transparent Huge Pages (Persistent)
Add to `/etc/rc.local`:
```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

#### Optimize PostgreSQL
Edit `/var/lib/pgsql/data/postgresql.conf`:
```ini
max_connections = 500
shared_buffers = 256MB
effective_cache_size = 1GB
```

### 4. Monitoring and Maintenance

#### Enable Monitoring
- Configure Cloudera Manager alerts
- Setup email notifications
- Enable service health checks

#### Backup Strategy
- Regular database backups
- Configuration file backups
- Cluster metadata exports

## Important Files and Directories

### Cloudera Manager
- **Configuration**: `/etc/cloudera-scm-server/`
- **Logs**: `/var/log/cloudera-scm-server/`
- **Installation**: `/opt/cloudera/cm/`

### Cloudera Manager Agent
- **Configuration**: `/etc/cloudera-scm-agent/`
- **Logs**: `/var/log/cloudera-scm-agent/`

### PostgreSQL
- **Data Directory**: `/var/lib/pgsql/data/`
- **Configuration**: `/var/lib/pgsql/data/postgresql.conf`
- **Authentication**: `/var/lib/pgsql/data/pg_hba.conf`
- **Logs**: `/var/lib/pgsql/data/log/`

### Repository Configuration
- **Yum repos**: `/etc/yum.repos.d/cloudera-manager.repo`

## Key Commands Reference

### Service Management
```bash
# Cloudera Manager Server
sudo systemctl start cloudera-scm-server
sudo systemctl stop cloudera-scm-server
sudo systemctl status cloudera-scm-server

# Cloudera Manager Agent
sudo systemctl start cloudera-scm-agent
sudo systemctl stop cloudera-scm-agent
sudo systemctl status cloudera-scm-agent

# PostgreSQL
sudo systemctl start postgresql
sudo systemctl stop postgresql
sudo systemctl status postgresql
```

### Database Operations
```bash
# Connect to database as postgres user
sudo -u postgres psql

# Connect to scm database
sudo -u postgres psql -d scm

# Check database connections
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"
```

### Ansible Operations
```bash
# Test connectivity
ansible -i hosts.ini all_nodes -m ping

# Run ad-hoc commands
ansible -i hosts.ini all_nodes -m shell -a "uptime" -b

# Run playbook
ansible-playbook -i hosts.ini deploy-cm.yml

# Run with verbose output
ansible-playbook -i hosts.ini deploy-cm.yml -vvv
```

## Network Ports

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| SSH | 22 | TCP | Remote access |
| PostgreSQL | 5432 | TCP | Database connections |
| Cloudera Manager Server | 7180 | TCP | Web UI (HTTP) |
| Cloudera Manager Server | 7183 | TCP | Web UI (HTTPS) |
| Cloudera Manager Agents | 9000 | TCP | Heartbeat |

## Resources and References

- [Cloudera Manager Documentation](https://docs.cloudera.com/cloudera-manager/7.4.4/)
- [Cloudera Installation Guide](https://docs.cloudera.com/cloudera-manager/7.4.4/installation/topics/install-cm-overview.html)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Ansible Documentation](https://docs.ansible.com/)

## License

This deployment configuration is provided as-is for educational and deployment purposes.


**Note**: Always test in a development environment before deploying to production. Ensure all security best practices are followed, including changing default passwords, enabling encryption, and configuring proper firewall rules.
