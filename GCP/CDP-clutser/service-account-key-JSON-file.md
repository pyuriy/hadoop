### Prerequisites
- Access to the Google Cloud Console (console.cloud.google.com) with a project (e.g., your `cdp-test` project) and billing enabled.
- IAM permissions on your account: Service Account Admin (`roles/iam.serviceAccountAdmin`) and Service Account Key Admin (`roles/iam.serviceAccountKeyAdmin`) to create the service account and keys.
- For Cloudera CDP on GCP, the service account needs specific roles for provisioning the environment and Data Lake (e.g., FreeIPA and utility bases). Recommended roles include:
  - Compute Network Admin (`roles/compute.networkAdmin`)
  - Compute Security Admin (`roles/compute.securityAdmin`)
  - IAM Role Administrator (`roles/iam.roleAdmin`)
  - Security Admin (`roles/resourcemanager.securityAdmin`)
  - Service Account Admin (`roles/iam.serviceAccountAdmin`)
  - Service Account Key Admin (`roles/iam.serviceAccountKeyAdmin`)
  - Storage Admin (`roles/storage.admin`)
  - Viewer (`roles/viewer`)
  
  These ensure the service account can manage VPCs, firewalls, instances, and storage for your CDP cluster.

### Step 1: Create the Service Account
#### Using GCP Console:
1. Go to **IAM & Admin > Service Accounts** in the Console.
2. Click **+ Create Service Account**.
3. Enter details:
   - **Service account name:** `cdp-provisioning-sa` (or similar; descriptive for your CDP-test cluster).
   - **Service account ID:** Auto-generated (e.g., `cdp-provisioning-sa@cdp-test.iam.gserviceaccount.com`).
   - **Description:** "Service account for CDP provisioning in cdp-test project."
4. Click **Create and Continue**.
5. **Grant access (optional for now):** Skip and click **Done**. You'll assign roles next.

#### Using gcloud CLI:
```
gcloud iam service-accounts create cdp-provisioning-sa \
    --description="Service account for CDP provisioning in cdp-test project" \
    --display-name="CDP Provisioning SA"
```

### Step 2: Assign Required Roles to the Service Account
Roles can be assigned at the project level for broad access.

#### Using GCP Console:
1. In **IAM & Admin > IAM**, find your project (`cdp-test`).
2. Click **+ GRANT ACCESS**.
3. **New principals:** Enter the service account email (e.g., `cdp-provisioning-sa@cdp-test.iam.gserviceaccount.com`).
4. **Assign roles:** Select the roles listed in Prerequisites (search and add one by one).
5. Click **Save**.

#### Using gcloud CLI:
For each role (repeat for all):
```
gcloud projects add-iam-policy-binding cdp-test \
    --member="serviceAccount:cdp-provisioning-sa@cdp-test.iam.gserviceaccount.com" \
    --role="roles/compute.networkAdmin"
```
Replace `cdp-test` with your project ID, and the role as needed.

Verify: `gcloud projects get-iam-policy cdp-test --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:cdp-provisioning-sa"`

### Step 3: Create and Download the JSON Key File
A service account can have up to 10 keys; create one for your local/Terraform use.

#### Using GCP Console:
1. Go back to **IAM & Admin > Service Accounts**.
2. Click the service account (`cdp-provisioning-sa`).
3. Go to the **KEYS** tab.
4. Click **ADD KEY > Create new key**.
5. Select **JSON** as the key type.
6. Click **Create**. The JSON file (e.g., `cdp-test-12345abcd.json`) downloads automatically.

#### Using gcloud CLI:
```
gcloud iam service-accounts keys create cdp-provisioning-key.json \
    --iam-account=cdp-provisioning-sa@cdp-test.iam.gserviceaccount.com \
    --project=cdp-test
```
This saves `cdp-provisioning-key.json` locally.

### Step 4: Configure Authentication for CDP/Terraform
1. Set the environment variable:
   ```
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/cdp-provisioning-key.json"
   ```
   Add to `~/.bashrc` or `~/.zshrc` for persistence.

2. Verify:
   ```
   gcloud auth application-default print-access-token
   ```
   Or test with `gcloud projects describe cdp-test`.

For Cloudera CDP:
- Register this credential in the CDP Management Console: **Environments > Credentials > + GCP Credential**, upload the JSON, and name it (e.g., `cdp-test-cred`).
- Use it when creating your environment for the CDP-test cluster.

### Security Notes
- **Rotate keys:** Delete old keys periodically via Console/CLI (`gcloud iam service-accounts keys delete KEY_ID`).
- **Restrict access:** Use Workload Identity Federation for production instead of long-lived keys.
- **For Terraform:** In your `terraform.tfvars`, reference this for auth; the provider uses the env var.

If you encounter errors (e.g., quota limits), check IAM policies or request increases in the Console. For CDP-specific troubleshooting, refer to the environment creation logs.
