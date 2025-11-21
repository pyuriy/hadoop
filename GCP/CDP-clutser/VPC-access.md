# Steps to configure access to a GCP project with VPC

### Prerequisites
- A Google Cloud Platform (GCP) project with billing enabled.
- Your laptop's public IP address. To find it:
  - Visit [whatismyipaddress.com](https://whatismyipaddress.com) or run `curl ifconfig.me` in your terminal.
  - Note: If your IP is dynamic (changes), consider using a static IP or Cloud NAT for outbound, but for inbound access to GCP, use your current public IP in CIDR format (e.g., `203.0.113.1/32` for a single IP).
- IAM permissions: Compute Network Admin (for VPC creation) and Compute Security Admin (for firewall rules).
- Access to GCP Console (console.cloud.google.com) or gcloud CLI installed and authenticated (`gcloud auth login`).

**Warning:** Opening "all access" (e.g., all ports/protocols) from your IP is a security risk. Limit to necessary ports (e.g., SSH:22, HTTPS:443) if possible. This guide assumes you want full TCP/UDP access for simplicity; adjust as needed.

### Step 1: Create a VPC Network
If you don't have an existing VPC, create one. This sets up the isolated network for your project's resources.

#### Using GCP Console:
1. Go to **VPC Network > VPC networks** in the GCP Console.
2. Click **Create VPC network**.
3. Enter details:
   - **Name:** `my-vpc` (or your preferred name).
   - **Subnet creation mode:** Automatic (creates subnets in all regions) or Custom (for manual control).
   - If Custom:
     - Add a subnet: e.g., Name: `my-subnet`, Region: `us-central1`, IP address range: `10.0.0.0/24` (CIDR block; avoid overlaps).
     - Flow logs: Off (unless needed for auditing).
     - Private Google access: On (allows private access to Google APIs).
4. **Dynamic routing mode:** Regional (default).
5. **Firewall rules:** Create default (allows basic egress; we'll add ingress next).
6. Click **Create**.

#### Using gcloud CLI:
```
gcloud compute networks create my-vpc \
    --subnet-mode=auto \
    --description="VPC for project access from laptop"
```
- For custom subnet: Add `--add-subnets "subnet-1=10.0.0.0/24,us-central1"`.

Verify: Run `gcloud compute networks describe my-vpc` or check Console.

### Step 2: (Optional) Create Subnets
If using Custom mode or need additional subnets:
#### Console:
1. In **VPC networks > my-vpc > Subnets**, click **Add subnet**.
2. Details: Name: `additional-subnet`, Region: e.g., `europe-west1`, IP range: `10.1.0.0/24`.
3. Click **Add**.

#### CLI:
```
gcloud compute networks subnets create additional-subnet \
    --network=my-vpc \
    --region=us-central1 \
    --range=10.1.0.0/24
```

### Step 3: Create Firewall Rules to Allow Access from Your Laptop's IP
Firewall rules control inbound (ingress) traffic to VMs/instances in the VPC. We'll create a rule allowing all traffic (TCP/UDP/ICMP) from your IP to all instances (targets: all IPs in the VPC).

#### Using GCP Console:
1. Go to **VPC Network > Firewall** in the Console.
2. Click **Create firewall rule**.
3. Enter details for an "Allow All from Laptop" rule:
   - **Name:** `allow-laptop-all-access`.
   - **Network:** Select `my-vpc`.
   - **Direction of traffic:** Ingress.
   - **Action on match:** Allow.
   - **Targets:** All instances in the network (applies to all VMs tagged or in the VPC).
   - **Source IP ranges:** Your laptop IP in CIDR (e.g., `203.0.113.1/32`).
   - **Protocols and ports:** Allow all (select "All" under TCP and UDP; or specify e.g., `tcp:0-65535,udp:0-65535,icmp` for explicit full access).
   - **Description:** "Allow full access from laptop IP to project services."
4. Click **Create**.

**For targeted access (safer):**
- If only SSH/RDP: Set Protocols/ports to `tcp:22` (SSH) or `tcp:3389` (RDP).
- For web services: `tcp:80,443`.
- Tag VMs: In targets, use "Specified target tags" (e.g., `allow-laptop`) and add the tag to your instances.

#### Using gcloud CLI:
```
gcloud compute firewall-rules create allow-laptop-all-access \
    --network=my-vpc \
    --allow=all \
    --source-ranges=203.0.113.1/32 \
    --description="Allow full access from laptop IP"
```
- For specific ports: Replace `--allow=all` with `--allow=tcp:22,tcp:80,udp:53,icmp`.
- Apply to specific instances: Add `--target-tags=allow-laptop`.

Verify: Run `gcloud compute firewall-rules describe allow-laptop-all-access` or check Console.

### Step 4: Attach Resources to the VPC
To access "all services," ensure your project's VMs/services use this VPC:
1. **For new VMs:** When creating instances (Compute Engine > VM instances > Create instance), set Network: `my-vpc`, Subnetwork: e.g., `my-subnet`.
2. **For existing VMs:** Edit instance > Networking > Network interfaces > Edit > Network: `my-vpc`.
3. **Other services (e.g., GKE clusters, App Engine):** Configure them to use the VPC (e.g., via VPC peering or shared VPC if multi-project).

#### CLI Example (Create VM in VPC):
```
gcloud compute instances create my-vm \
    --zone=us-central1-a \
    --network=my-vpc \
    --subnet=my-subnet \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --tags=allow-laptop  # If using tag-based rules
```

### Step 5: Test Access
1. Launch a test VM in the VPC (as above).
2. From your laptop:
   - SSH: `gcloud compute ssh my-vm --zone=us-central1-a` (or `ssh user@external-ip` using your key).
   - Ping: `ping <vm-external-ip>` (enable ICMP in firewall if needed).
   - Port scan (optional): Use `nmap -p 1-1000 <vm-external-ip>` to verify open ports.
3. Check logs: In Console > VPC Network > Firewall > View logs (enable if not already).

### Step 6: Security Best Practices and Cleanup
- **Restrict further:** Use HTTPS Load Balancers or Cloud IAP for production access instead of direct IP rules.
- **Monitor:** Enable VPC Flow Logs for auditing.
- **Dynamic IP handling:** If your IP changes, update the firewall rule or use Cloud Armor with IP allowlists.
- **Cleanup:** Delete rules/VMs/VPC via Console (select > Delete) or `gcloud compute firewall-rules delete allow-laptop-all-access` and `gcloud compute networks delete my-vpc`.

If your project spans multiple regions/services, consider Shared VPC for centralized management. For Cloudera CDP integration (from prior context), ensure the VPC aligns with CDP's requirements (e.g., no overlapping CIDRs). Refer to [GCP VPC docs](https://cloud.google.com/vpc/docs) for advanced configs.
