You need to enable the Compute Engine API in your GCP project to create and manage VPC networks, subnets, firewall rules, and virtual machine (VM) instances. While basic VPC creation might work without it in some cases, enabling the API is required for full functionality, including attaching resources like VMs and testing access as outlined in the previous steps.

### Quick Steps to Enable the Compute Engine API

#### Using GCP Console:
1. Go to the [Google Cloud Console](https://console.cloud.google.com/apis/library).
2. Select your project from the dropdown at the top.
3. In the search bar, type **Compute Engine API**.
4. Click on **Compute Engine API** from the results.
5. If not already enabled, click **Enable**.

#### Using gcloud CLI:
```
gcloud services enable compute.googleapis.com
```

Verify it's enabled:
```
gcloud services list --enabled | grep compute
```

Once enabled, proceed with the VPC creation steps from before. If you encounter quota issues (e.g., for VMs), request increases via the Console under **IAM & Admin > Quotas**.
