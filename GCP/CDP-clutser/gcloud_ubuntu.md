### Installing Google Cloud CLI (gcloud SDK) on Ubuntu 18.04

The Google Cloud CLI (formerly known as the Google Cloud SDK) provides tools like `gcloud`, `gsutil`, and `bq` for managing GCP resources. Ubuntu 18.04 is fully supported. These instructions are based on the official guide and should take about 5-10 minutes.

#### Prerequisites
- A running Ubuntu 18.04 system with sudo access.
- Internet connectivity.
- Update your package list:
  ```
  sudo apt-get update
  ```
- Install required dependencies:
  ```
  sudo apt-get install apt-transport-https ca-certificates gnupg curl
  ```

#### Step-by-Step Installation
1. **Import the Google Cloud public key** (for secure package verification):
   ```
   curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
   ```

2. **Add the Google Cloud CLI distribution URI as a package source**:
   ```
   echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
   ```

3. **Update the package list and install the Google Cloud CLI**:
   ```
   sudo apt-get update && sudo apt-get install google-cloud-cli
   ```
   This installs the core components (`gcloud`, `gsutil`, `bq`, etc.). For additional components (e.g., `kubectl` for Kubernetes or App Engine extensions), install them separately:
   ```
   sudo apt-get install google-cloud-cli-kubectl  # Example for kubectl
   ```

#### Initialization and Setup
1. **Initialize the CLI** (this sets up authentication, default project, and region):
   ```
   gcloud init
   ```
   - Follow the prompts: It will open a browser for login (or use `gcloud init --console-only` for CLI-only).
   - Select or create a GCP project.
   - Configure default compute region/zone if needed.

2. **Verify the installation**:
   ```
   gcloud --version
   ```
   You should see output like `Google Cloud SDK 471.0.0` (version may vary).

#### Additional Notes
- **Path Configuration:** The tools are added to your PATH automatically. If not, add `export PATH=$PATH:/usr/bin/google-cloud-sdk/bin` to your `~/.bashrc` and run `source ~/.bashrc`.
- **Updates:** To update: `sudo apt-get update && sudo apt-get upgrade google-cloud-cli`.
- **Uninstallation:** `sudo apt-get remove google-cloud-cli && sudo apt-get autoremove && sudo rm /etc/apt/sources.list.d/google-cloud-sdk.list`.
- **Troubleshooting:** If you encounter key errors, ensure `curl` works and retry the import step. For older versions (pre-371.0.0), the package was named `google-cloud-sdk`—but use the current name for the latest.
- **Supported Components:** Core install doesn't include everything (e.g., no `kubectl` by default). List available: `apt-cache search google-cloud-cli`.

For more details or platform-specific tweaks, refer to the official documentation.
