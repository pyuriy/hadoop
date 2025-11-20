### Prerequisites for Deploying Cloudera CDP Cluster on GCP Using Terraform

Before starting, ensure you have:
- A Google Cloud Platform (GCP) account with billing enabled.
- A Cloudera Data Platform (CDP) account (sign up for a free trial at [cloudera.com](https://www.cloudera.com)).
- Terraform installed (version 1.0 or higher; download from [terraform.io](https://www.terraform.io/downloads)).
- GCP authentication configured:
  - Install the Google Cloud SDK and run `gcloud auth application-default login`.
  - Or, create a service account key JSON file and set `export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json`.
- Required IAM roles for your GCP service account or user: Compute Network Admin, Compute Security Admin, Role Administrator, Security Admin, Service Account Admin, Service Account Key Admin, Storage Admin, Viewer.
- CDP CLI installed and configured with credentials (run `cdp config` to set up `~/.cdp/credentials` with your CDP username and private key).

The deployment uses Cloudera's official Terraform quickstart repository, which provisions GCP resources (VPC, subnets, firewall rules, etc.), creates a CDP environment, and deploys a Data Lake. After infrastructure setup, you'll create a Data Hub cluster (virtual cluster) using the Cloudera CDP Terraform provider.

**Estimated Time:** 60 minutes for infrastructure + 20-30 minutes for Data Hub creation.

### Step 1: Clone the Repository and Prepare Configuration

1. Clone the Cloudera CDP Terraform quickstarts repository:
   ```
   git clone https://github.com/cloudera-labs/cdp-tf-quickstarts.git
   cd cdp-tf-quickstarts/gcp
   ```

2. Copy and edit the variables template:
   ```
   cp terraform.tfvars.template terraform.tfvars
   ```
   Edit `terraform.tfvars` with your values. Here's a comprehensive example for a public deployment (adjust for `semi-private` or `private` templates as needed for network isolation):

   ```
   # ------- Global settings -------
   env_prefix = "cdp-demo"  # Required: Prefix for all resources (lowercase letters, numbers, hyphens; <=12 chars)

   # ------- Cloud Settings -------
   gcp_project = "your-gcp-project-id"  # Your GCP project ID
   gcp_region = "us-central1"  # GCP region (e.g., us-central1, europe-west4)

   # ------- CDP Environment Deployment -------
   deployment_template = "public"  # Options: public, semi-private, private (affects networking and scale)
   datalake_scale = null  # Optional: Override scale (e.g., LIGHT_DUTY for public; defaults based on template)

   # ------- Networking (Optional: Defaults to creating new VPC) -------
   create_vpc = true  # Set to false if using existing VPC
   cdp_vpc_name = null  # If create_vpc=false, specify existing VPC name
   cdp_subnet_names = []  # If create_vpc=false, list existing subnet names (one per AZ)
   cdp_secondary_ranges = {}  # Optional: Custom secondary IP ranges for subnets

   # ------- SSH Access (Optional) -------
   public_key_text = null  # Optional: Paste your SSH public key here (e.g., ssh-rsa AAAAB3N...); defaults to auto-generated keypair saved as cdp-demo-ssh-key.pem
   ingress_extra_cidrs_and_ports = []  # Optional: Extra CIDRs/ports for ingress (e.g., [{"cidr": "your-ip/32", "ports": [22, 443]}]); defaults to your public IP

   # ------- Tags (Optional) -------
   env_tags = {
     owner    = "your-team"
     project  = "cdp-poc"
     enddate  = "2025-12-31"
   }
   ```

   - **Deployment Templates Explanation:**
     | Template     | Description | Use Case | Data Lake Scale Default |
     |--------------|-------------|----------|-------------------------|
     | `public`    | Fully public access; simplest setup. | Development/POC | LIGHT_DUTY |
     | `semi-private` | Private subnets with NAT for outbound. | Production with limited exposure | ENTERPRISE |
     | `private`   | Fully private; requires VPN/Direct Connect. | High security | ENTERPRISE |

3. (Optional) Extend variables for custom sizing (e.g., larger FreeIPA instances). Edit `variables.tf` to add:
   ```
   variable "freeipa_instance_type" {
     type        = string
     description = "GCP machine type for FreeIPA instances"
     default     = null
   }
   ```
   Then update `main.tf` to pass it to the module:
   ```
   freeipa_instance_type = var.freeipa_instance_type
   ```
   And set in `terraform.tfvars`:
   ```
   freeipa_instance_type = "n1-standard-4"
   ```

### Step 2: Deploy the CDP Environment and Data Lake

The quickstart uses the `terraform-cdp-modules` GitHub repo as a remote module source. Here's the full Terraform code for the GCP quickstart (files in `gcp/` directory):

#### `main.tf` (Provider and Module Invocation)
```
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    cloudera = {
      source  = "cloudera/cdp"
      version = "~> 0.2"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

# Deploy GCP pre-reqs (VPC, subnets, firewall, service account, etc.)
module "gcp_prereqs" {
  source = "git::https://github.com/cloudera-labs/terraform-cdp-modules.git//modules/terraform-cdp-gcp-pre-reqs?ref=v0.10.2"

  env_prefix              = var.env_prefix
  gcp_project             = var.gcp_project
  gcp_region              = var.gcp_region
  deployment_template     = var.deployment_template
  create_vpc              = var.create_vpc
  cdp_vpc_name            = var.cdp_vpc_name
  cdp_subnet_names        = var.cdp_subnet_names
  cdp_secondary_ranges    = var.cdp_secondary_ranges
  public_key_text         = var.public_key_text
  ingress_extra_cidrs_and_ports = var.ingress_extra_cidrs_and_ports
  env_tags                = var.env_tags
}

# Deploy CDP Environment and Data Lake
module "cdp_deploy" {
  source = "git::https://github.com/cloudera-labs/terraform-cdp-modules.git//modules/terraform-cdp-deploy?ref=v0.10.2"

  env_prefix          = var.env_prefix
  deployment_template = var.deployment_template
  datalake_scale      = var.datalake_scale

  # GCP-specific inputs from pre-reqs module
  gcp_project             = var.gcp_project
  gcp_region              = var.gcp_region
  cdp_vpc_id              = module.gcp_prereqs.cdp_vpc_id
  cdp_subnet_ids          = module.gcp_prereqs.cdp_subnet_ids
  cdp_proxy_config        = module.gcp_prereqs.cdp_proxy_config
  gcp_freeipa_sa_email    = module.gcp_prereqs.gcp_freeipa_sa_email
  gcp_freeipa_sa_json_key = module.gcp_prereqs.gcp_freeipa_sa_json_key
  gcp_utility_sa_email    = module.gcp_prereqs.gcp_utility_sa_email
  gcp_utility_sa_json_key = module.gcp_prereqs.gcp_utility_sa_json_key

  # SSH
  ssh_private_key = module.gcp_prereqs.ssh_private_key
  ssh_public_key  = module.gcp_prereqs.ssh_public_key

  # Tags
  env_tags = var.env_tags

  depends_on = [module.gcp_prereqs]
}
```

#### `variables.tf` (Input Variables)
```
variable "env_prefix" {
  type        = string
  description = "Prefix for all resources"
}

variable "gcp_project" {
  type        = string
  description = "GCP Project ID"
}

variable "gcp_region" {
  type        = string
  description = "GCP Region"
}

variable "deployment_template" {
  type        = string
  description = "Deployment template: public, semi-private, private"
  default     = "public"
}

variable "datalake_scale" {
  type        = string
  description = "Data Lake scale preset"
  default     = null
}

variable "create_vpc" {
  type        = bool
  description = "Create new VPC"
  default     = true
}

variable "cdp_vpc_name" {
  type        = string
  description = "Existing VPC name"
  default     = null
}

variable "cdp_subnet_names" {
  type        = list(string)
  description = "Existing subnet names"
  default     = []
}

variable "cdp_secondary_ranges" {
  type        = map(string)
  description = "Secondary IP ranges"
  default     = {}
}

variable "public_key_text" {
  type        = string
  description = "SSH public key text"
  default     = null
}

variable "ingress_extra_cidrs_and_ports" {
  type        = list(map(string))
  description = "Extra ingress CIDRs and ports"
  default     = []
}

variable "env_tags" {
  type        = map(string)
  description = "Environment tags"
  default     = {}
}
```

#### `outputs.tf` (Key Outputs)
```
output "environment_name" {
  value = module.cdp_deploy.environment_name
}

output "datalake_name" {
  value = module.cdp_deploy.datalake_name
}

output "ssh_private_key" {
  value     = module.gcp_prereqs.ssh_private_key
  sensitive = true
}

output "cdp_vpc_id" {
  value = module.gcp_prereqs.cdp_vpc_id
}
```

4. Initialize and apply:
   ```
   terraform init
   terraform plan  # Review the plan
   terraform apply  # Type 'yes' to confirm
   ```
   Monitor progress in the GCP Console (VPC, Compute Engine) or CDP Console at https://data.cloudera.com.

   Outputs will include `environment_name` (e.g., `cdp-demo-env`) and `datalake_name` (e.g., `cdp-demo-dl`).

### Step 3: Create a Data Hub Cluster (Virtual Cluster) Using CDP Provider

Once the environment is ready (status: "Running" in CDP Console), add a Data Hub cluster. Create a new directory (e.g., `datahub.tf`) and use the Cloudera CDP provider. Install the provider via `terraform init`.

#### Example `datahub.tf` for a Basic Data Hub Cluster (Spark/Izzy Template)
```
terraform {
  required_providers {
    cloudera = {
      source  = "cloudera/cdp"
      version = "~> 0.2.0"
    }
  }
}

provider "cloudera" {
  # Uses ~/.cdp/credentials; or set altus_profile = "your-profile"
}

# Replace with outputs from Step 2
locals {
  environment_name = "cdp-demo-env"  # From terraform output
  datalake_name    = "cdp-demo-dl"   # From terraform output
}

resource "cloudera_datahub" "gcp_spark_cluster" {
  name                = "gcp-spark-cluster"
  environment_name    = local.environment_name
  datalake_name       = local.datalake_name
  cluster_template_name = "GCP - Spark Izzy"  # Or "GCP - Default" for basic; list via CDP CLI: cdp datahub list-cluster-templates --environment-name <env>
  instance_group {
    name               = "gateway"
    instance_group_type = "GATEWAY"
    instance_count     = 1
    instance_type      = "n1-standard-4"  # GCP machine type
    root_volume_size   = 100
    data_volume_sizes  = [100, 100]
  }
  instance_group {
    name               = "core"
    instance_group_type = "CORE"
    instance_count     = 3
    instance_type      = "n1-standard-8"
    root_volume_size   = 100
    data_volume_sizes  = [200, 200, 200]
  }
  runtime {
    cdh_version = "7.2.18"  # Latest CDH version; check docs for supported
  }
  credentials {
    ssh_key = file("~/.ssh/id_rsa.pub")  # Or use the key from Step 2
  }

  # Optional: Scaling config
  auto_scaling_config_name = null  # Or reference an existing auto-scale policy
}

output "datahub_name" {
  value = cloudera_datahub.gcp_spark_cluster.name
}
```

Run:
```
terraform init
terraform apply
```

- **Customization Notes:**
  - **Cluster Templates:** Use CDP CLI (`cdp datahub list-cluster-templates`) for GCP-specific templates like "GCP - DataFlow" or "GCP - Hive".
  - **Sizing:** Adjust `instance_count` and `instance_type` based on workload (e.g., n1-highmem-8 for memory-intensive).
  - **Storage:** Volumes in GB; add more for larger datasets.
  - Monitor in CDP Console: Data Hub > Clusters. Status goes to "Running" in ~15-20 minutes.

### Step 4: Verify and Access the Cluster

1. Log in to CDP Console: https://data.cloudera.com.
2. Navigate to **Management Console > Data Hub > Clusters** – confirm "gcp-spark-cluster" is running.
3. Access Hue (web UI): From cluster details, click "Hue" (requires bastion or VPN for private setups).
4. SSH to nodes: Use the private key and external IPs from GCP Console.
5. Run jobs: Submit Spark jobs via Hue or CLI (`cdp datahub run-command`).

### Cleanup

To tear down:
1. Destroy Data Hub: `terraform destroy` in the datahub directory.
2. Destroy environment: `terraform destroy` in the gcp directory (wait ~20 minutes).

For troubleshooting:
- Check Terraform logs for errors.
- Review CDP flow logs in Console.
- Ensure quotas: Request increases for Compute/Storage if needed.

This setup provisions a fully functional CDP cluster on GCP. For advanced configs (e.g., custom VPC peering), refer to Cloudera docs.
