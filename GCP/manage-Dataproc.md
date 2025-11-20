# Dataproc healt managemnet 

Google Cloud Dataproc does **not** use Apache Ambari.

Ambari is designed for "long-running, pet clusters" (where you manually restart services, tweak configs, and nurse the cluster). Dataproc is a managed service designed for **ephemeral clusters** (you spin them up, run a job, and delete them).

Because Google manages the "health" of the nodes for you, the traditional "Ambari Dashboard" is replaced by the **Google Cloud Console** + **Component Gateway**.

Here is how you perform common "Ambari tasks" in the Dataproc world:

### **1. Service Status & Health (The "Dashboard" Replacement)**

In Ambari, you see green/red lights for HDFS, YARN, etc.

  * **In Dataproc:** You don't monitor individual services (like "Is HiveServer2 up?"). You monitor the **Cluster Status** in the Google Cloud Console.
  * **If a service fails:** Dataproc automatically tries to restart it. If a node fails, Dataproc repairs it or you delete/recreate the cluster.
  * **Detailed Metrics:** Use **Cloud Monitoring** (Stackdriver). It has built-in dashboards for YARN memory, HDFS capacity, and CPU usage.

### **2. Accessing UIs (The "Quick Links" Replacement)**

Ambari gave you links to the Resource Manager, NameNode, etc.

  * **In Dataproc:** Use the **Component Gateway**.
  * **How to use it:**
    1.  Go to the Dataproc Cluster list in the console.
    2.  Click your cluster name.
    3.  Click the **"Web Interfaces"** tab.
    4.  You will see direct, authenticated links to **YARN, HDFS NameNode, Spark History Server, MapReduce Job History,** etc.

### **3. Configuration Management (The "Configs" Tab Replacement)**

In Ambari, you used a UI to change `core-site.xml` or `hive-site.xml`.

  * **In Dataproc:** You set configurations **at cluster creation time** using "Cluster Properties."
  * **Example:** Instead of clicking a checkbox in Ambari to change a memory setting, you pass a flag:
    ```bash
    gcloud dataproc clusters create my-cluster \
        --properties yarn:yarn.nodemanager.resource.memory-mb=16384
    ```
  * **Post-Creation:** You generally **cannot** change these configs easily on a running cluster via a UI. This is a major shift. If you need a config change, the "Cloud Native" way is to **spin up a new cluster** with the new config, rather than patching the old one.

### **4. Installing Add-ons (The "Add Service" Wizard Replacement)**

In Ambari, you used a wizard to add Solr or Kafka.

  * **In Dataproc:** Use **"Optional Components"** or **"Initialization Actions"**.
  * **Optional Components:** Checkboxes during creation for popular tools (Jupyter, Zeppelin, Presto, Solr, Ranger).
  * **Initialization Actions:** Bash scripts that run on every node startup to install anything else you want.

### **Comparison Summary**

| Feature | Apache Ambari | Google Cloud Dataproc |
| :--- | :--- | :--- |
| **Philosophy** | "Maintain this cluster forever" | "Cattle, not pets" (Delete & Recreate) |
| **Service Start/Stop** | Buttons in Web UI | `gcloud` commands or automated by GCP |
| **Config Changes** | UI Wizard + Restart Required | Cluster Properties (set at creation) |
| **Log Viewing** | Ambari Log Search | **Cloud Logging** (Centralized & Searchable) |
| **Security** | Ambari Views / Ranger | **IAM** (Google Identity) + **Component Gateway** |


