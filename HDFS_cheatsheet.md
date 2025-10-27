# Comprehensive Hadoop HDFS Cheatsheet

## What is HDFS?
HDFS (Hadoop Distributed File System) is a distributed, scalable, and fault-tolerant file system designed for storing and processing large datasets across clusters of commodity hardware. It provides high-throughput access to data and is optimized for large files with streaming data access patterns.

## Architecture Overview
HDFS follows a **master-slave architecture**:
- **NameNode (Master)**: Manages the filesystem namespace, metadata, and block locations. It does not store actual data.
- **DataNode (Slave)**: Stores actual data blocks and handles read/write requests. Reports block status to NameNode periodically.
- **Secondary NameNode**: Assists NameNode by checkpointing edits and fsimage files (not a hot standby).
- **Client**: Interacts with NameNode for metadata and directly with DataNodes for data I/O.

Files are split into **blocks** (default 128 MB) and replicated across DataNodes (default replication factor: 3) for fault tolerance.

## Key Concepts
| Concept | Description |
|---------|-------------|
| **Block** | Fixed-size chunk of a file (128 MB or 256 MB default). Enables parallel processing. |
| **Replication** | Copies of blocks stored on multiple DataNodes for reliability (configurable per file/directory). |
| **Fault Tolerance** | Automatic block replication and re-replication if a DataNode fails. |
| **Rack Awareness** | Placement policy to minimize network traffic by preferring blocks on the same rack. |
| **Erasure Coding** | Space-efficient alternative to replication for cold data (e.g., RS-3-2 policy). |
| **Snapshots** | Point-in-time copies of directories for backup/recovery. |
| **Federation** | Multiple independent NameNodes to scale namespace. |
| **High Availability (HA)** | Active-standby NameNodes with shared storage (e.g., Quorum Journal Manager). |

## Common Configurations
Edit `hdfs-site.xml` for cluster-wide settings. Key parameters:

| Property | Description | Default/Example |
|----------|-------------|-----------------|
| `dfs.blocksize` | Block size in bytes. | `134217728` (128 MB) |
| `dfs.replication` | Default replication factor. | `3` |
| `dfs.namenode.name.dir` | Directory for fsimage and edits. | `/tmp/hadoop-hdfs/namenode` |
| `dfs.datanode.data.dir` | Directories for block storage. | `/tmp/hadoop-hdfs/datanode` |
| `dfs.permissions.enabled` | Enable/disable permission checks. | `true` |
| `dfs.encryption.key.provider.uri` | URI for key provider in encryption zones. | N/A |
| `dfs.ec.policy.default` | Default erasure coding policy. | `RS-DEFAULT` |

Restart services after changes. Use `hdfs getconf` to retrieve values.

## HDFS Commands
All commands use `hdfs` script. Syntax: `hdfs [SHELL_OPTIONS] COMMAND [GENERIC_OPTIONS] [COMMAND_OPTIONS]`.

### Generic Options
| Option | Description |
|--------|-------------|
| `-fs <URI>` | Filesystem URI (e.g., `hdfs://nn:9000`). |
| `-conf <file>` | Alternate config file. |
| `-loglevel <level>` | Logging level (e.g., `DEBUG`). |
| `-help, -h` | Help info. |

### User Commands (File System Shell: `hdfs dfs`)
For everyday file operations. Equivalent to `hadoop fs`.

| Command | Description | Example |
|---------|-------------|---------|
| `hdfs dfs -ls <path>` | List files/directories. | `hdfs dfs -ls /user` |
| `hdfs dfs -mkdir <path>` | Create directory. | `hdfs dfs -mkdir /data/input` |
| `hdfs dfs -put <local> <hdfs>` | Copy from local to HDFS. | `hdfs dfs -put local.txt /data/` |
| `hdfs dfs -get <hdfs> <local>` | Copy from HDFS to local. | `hdfs dfs -get /data/file.txt .` |
| `hdfs dfs -copyFromLocal <local> <hdfs>` | Alias for `-put`. | `hdfs dfs -copyFromLocal *.csv /data/` |
| `hdfs dfs -copyToLocal <hdfs> <local>` | Alias for `-get`. | `hdfs dfs -copyToLocal /data/ localdir` |
| `hdfs dfs -mv <src> <dst>` | Move/rename file or directory. | `hdfs dfs -mv /data/old /data/new` |
| `hdfs dfs -cp <src> <dst>` | Copy within HDFS. | `hdfs dfs -cp /data/src /data/dest` |
| `hdfs dfs -rm <path>` | Delete file. | `hdfs dfs -rm /data/file.txt` |
| `hdfs dfs -rm -r <path>` | Recursively delete directory. | `hdfs dfs -rm -r /data/dir` |
| `hdfs dfs -du <path>` | Disk usage (bytes). | `hdfs dfs -du -h /data` (human-readable) |
| `hdfs dfs -count <path>` | Count files, directories, size. | `hdfs dfs -count /data` |
| `hdfs dfs -cat <path>` | Display file contents. | `hdfs dfs -cat /data/file.txt` |
| `hdfs dfs -tail <path>` | Last 1KB of file. | `hdfs dfs -tail /data/log.txt` |
| `hdfs dfs -head <path>` | First 1KB of file. | `hdfs dfs -head /data/file.txt` |
| `hdfs dfs -touchz <path>` | Create empty file. | `hdfs dfs -touchz /data/empty.txt` |
| `hdfs dfs -chmod <mode> <path>` | Change permissions. | `hdfs dfs -chmod 755 /data/file` |
| `hdfs dfs -chown <user:group> <path>` | Change owner/group. | `hdfs dfs -chown alice:users /data/` |
| `hdfs dfs -setrep <n> <path>` | Set replication factor. | `hdfs dfs -setrep 2 /data/file.txt` |
| `hdfs dfs -df <path>` | Available space. | `hdfs dfs -df -h /` |
| `hdfs dfs -stat <format> <path>` | File stats. | `hdfs dfs -stat "%B" /data/file` (%B=size) |
| `hdfs dfs -test -e <path>` | Test if path exists. | `hdfs dfs -test -e /data/file` (exit 0 if true) |
| `hdfs dfs -getmerge <hdfs> <local>` | Merge small files to one. | `hdfs dfs -getmerge /data/splits output.txt` |

### Administration Commands (`hdfs dfsadmin`, etc.)
Require superuser privileges.

| Command | Description | Example |
|---------|-------------|---------|
| `hdfs dfsadmin -report` | Cluster status (nodes, capacity). | `hdfs dfsadmin -report` |
| `hdfs balancer -threshold <n>` | Rebalance blocks (<10% deviation). | `hdfs balancer -threshold 5` |
| `hdfs dfsadmin -setSpaceQuota <bytes> <path>` | Set space quota. | `hdfs dfsadmin -setSpaceQuota 1g /user` |
| `hdfs dfsadmin -setQuota <n> <path>` | Set namespace quota (files). | `hdfs dfsadmin -setQuota 10000 /user` |
| `hdfs dfsadmin -refreshNodes` | Reload DataNode list. | `hdfs dfsadmin -refreshNodes` |
| `hdfs fsck <path> -files -blocks` | Filesystem check. | `hdfs fsck / -files -blocks -locations` |
| `hdfs snapshot -create <snapname> <path>` | Create snapshot. | `hdfs snapshot -create /data mysnap` |
| `hdfs snapshot -list <path>` | List snapshots. | `hdfs snapshot -list /data` |
| `hdfs cacheadmin -addPool <pool>` | Add cache pool. | `hdfs cacheadmin -addPool mypool` |
| `hdfs storagepolicies -listPolicies` | List storage policies. | `hdfs storagepolicies -listPolicies` |
| `hdfs storagepolicies -setStoragePolicy -path <path> -policy <policy>` | Set policy (HOT, WARM, COLD). | `hdfs storagepolicies -setStoragePolicy -path /data -policy HOT` |
| `hdfs ec -listPolicies` | List erasure coding policies. | `hdfs ec -listPolicies` |
| `hdfs ec -setPolicy -policy <policy> -path <path>` | Apply EC policy. | `hdfs ec -setPolicy -policy RS-3-2 -path /data` |
| `hdfs haadmin -failover <nn1> <nn2>` | Manual failover in HA. | `hdfs haadmin -failover nn1 nn2` |

### Other Useful Commands
| Command | Description | Example |
|---------|-------------|---------|
| `hdfs version` | Hadoop version. | `hdfs version` |
| `hdfs getconf -namenodes` | List NameNodes. | `hdfs getconf -namenodes` |
| `hdfs groups <user>` | User's groups. | `hdfs groups alice` |
| `hdfs fetchdt --renew` | Renew delegation token. | `hdfs fetchdt --webservice http://nn:9870 --renew` |
| `hdfs oiv -p XML -i <fsimage> -o <out>` | View fsimage. | `hdfs oiv -p XML -i fsimage_000 -o out.xml` |
| `hdfs mover -p <src> <dst>` | Migrate blocks to new storage. | `hdfs mover -p /old /new` |
| `hdfs diskbalancer -plan <node>` | Balance disks on DataNode. | `hdfs diskbalancer -plan -node dn1.example.com` |

## Tips
- Use `-h` for human-readable output (e.g., sizes in GB).
- For large clusters, use web UI: NameNode at `http://nn:9870`.
- Monitor with `hdfs dfsadmin -report` or JMX (`hdfs jmxget`).
- Security: Enable Kerberos for authentication; use ACLs for fine-grained access.

This cheatsheet is compiled from official and community sources for quick reference. For full details, refer to Apache Hadoop documentation.

# HDFS NameNode: Detailed Overview

The NameNode is the cornerstone of the Hadoop Distributed File System (HDFS), acting as the master server in its master/slave architecture. It manages the filesystem namespace, metadata, and access control without handling actual data transfer—user data flows directly between clients and DataNodes. Below is a comprehensive breakdown of its role, components, operations, and interactions.

## Role and Responsibilities
- **Central Authority**: The NameNode maintains the entire filesystem namespace in memory, including the hierarchical structure of directories and files, file permissions, quotas, and mappings of files to data blocks.
- **Access Regulation**: It authorizes client operations (e.g., open, close, rename) and directs clients to the appropriate DataNodes for data I/O.
- **Block Coordination**: Tracks block locations across DataNodes, enforces replication factors (default: 3), and ensures fault tolerance through re-replication.
- **No Data Storage**: It stores only metadata (typically a few GB for large clusters), not the actual data blocks.

Key design principle: User data never passes through the NameNode, enabling high-throughput streaming access.

## Filesystem Namespace
HDFS supports a Unix-like hierarchical namespace:
- Operations: Create/delete/rename files and directories, set permissions/quotas.
- Limitations: No hard/soft links or random writes (append-only for files).
- Reserved Paths: System paths like `/.reserved` (for internal use) and `.snapshot` (for backups).

The namespace is kept fully in memory for fast access, with persistence handled separately (see below).

## Metadata Management
The NameNode stores two main types of metadata:
- **Namespace Metadata**: Directory/file hierarchy, permissions, modification times.
- **Block Metadata**: File-to-block mappings, block locations (DataNode IDs), replication factors.

This metadata is loaded into memory on startup and updated in real-time for all operations.

## Persistence Mechanisms: FsImage and EditLog
To ensure durability and recoverability, the NameNode uses a dual-file persistence model:

| Component | Description | Storage | Role in Operations |
|-----------|-------------|---------|--------------------|
| **FsImage** | Persistent snapshot of the filesystem namespace and block mappings at a point in time. | Local disk (e.g., `dfs.namenode.name.dir`). | Loaded on startup; serves as the base for recovery. |
| **EditLog** | Sequential, append-only transaction log recording every metadata change (e.g., file creation, replication updates). | Local disk (same directory as FsImage). | Appended synchronously for each operation; ensures atomicity. |

### How Persistence Works
1. **On Startup**: NameNode loads the latest FsImage into memory, then replays the EditLog to apply recent changes.
2. **During Runtime**: All mutations (e.g., writes) are appended to the EditLog and reflected in memory immediately.
3. **Checkpointing**: Periodically (configurable via `dfs.namenode.checkpoint.period` or after `dfs.namenode.checkpoint.txns` transactions):
   - Merge EditLog into FsImage to create an updated snapshot.
   - Truncate the EditLog (old entries are now in FsImage).
   - This reduces recovery time on restart by minimizing EditLog replay.

Without checkpointing, EditLogs can grow large, slowing startups. Multiple copies of these files can be configured for redundancy.

## Secondary NameNode
The Secondary NameNode is a helper daemon (not a hot standby):
- **Functions**:
  - Downloads FsImage and EditLog from the active NameNode periodically.
  - Merges them into a new FsImage (offloads checkpointing from the primary).
  - Uploads the updated FsImage back.
- **Configuration**: Runs on a separate machine; sync interval via `dfs.namenode.checkpoint.dir`.
- **Limitations**: It cannot take over if the primary fails—it's for maintenance, not HA. For failover, use HDFS High Availability (HA) with active/standby NameNodes and shared storage (e.g., Quorum Journal Manager).

In production, Secondary NameNode is often combined with HA setups.

## Block Management
Blocks (default 128 MB) are the unit of storage and parallelism:
- **Mapping**: NameNode maintains an in-memory map of file blocks to DataNode locations.
- **Replication**:
  - Ensures the specified number of replicas per block.
  - Placement policy (rack-aware): For factor=3, prefers 2 replicas on the same rack, 1 on another for fault tolerance.
- **Under-Replicated/Over-Replicated Handling**: Automatically triggers re-replication or deletion as needed.

| Replication Scenario | Placement Strategy |
|----------------------|--------------------|
| Factor = 3 | 1 local rack (writer's node), 1 same rack, 1 remote rack. |
| Factor > 3 | Additional replicas distributed to avoid rack overload. |
| Hot/Cold Data | Uses storage policies (HOT: SSD; COLD: archival) for placement. |

## Interactions with DataNodes and Clients
Communication uses TCP/IP and RPC protocols:
- **With Clients**:
  - Client requests metadata (e.g., block locations) via the Client Protocol.
  - NameNode responds with DataNode addresses; client then reads/writes directly to DataNodes.
- **With DataNodes** (DataNode Protocol):
  - **Heartbeats**: DataNodes send every few seconds to report liveness. Missing heartbeats mark a node as dead.
  - **Block Reports**: Sent periodically (or on startup) listing all stored blocks. NameNode uses this to update its block map.
  - **Commands**: NameNode issues instructions like "replicate block X to node Y" via RPC responses.

The NameNode is reactive—it responds to requests but doesn't initiate connections.

## Safemode and Startup
- **Safemode**: Entered on startup or after failover. No mutations (e.g., replication) occur until:
  - A configurable percentage of blocks are reported (via Block Reports).
  - A 30-second grace period passes.
- **Exit Command**: `hdfs dfsadmin -safemode leave` (admin only).
- Purpose: Ensures metadata consistency before allowing writes.

## High Availability (HA) and Robustness
- **Single Point of Failure Mitigation**: Use HA with:
  - **Active/Standby NameNodes**: Shared EditLog via JournalNodes (QJM) or NFS.
  - **Failover**: Automatic (ZKFailoverController) or manual (`hdfs haadmin -failover`).
- **Failure Handling**:
  - NameNode Crash: Standby takes over using shared logs.
  - DataNode Failure: Detect via heartbeats; re-replicate affected blocks.
- **Integrity**: Clients verify data with checksums; metadata uses CRC for corruption detection.
- **Scalability**: Federation allows multiple independent NameNodes for namespace partitioning.

## Monitoring and Best Practices
- **Web UI**: Access at `http://namenode:9870` for namespace browser, reports, and logs.
- **Logs**: Check `hadoop-hdfs-namenode*.log` for EditLog/FsImage issues.
- **Tuning**: Increase `dfs.namenode.edits.journaltail` for faster tailing in HA.
- **Backup**: Regularly snapshot metadata directories; use tools like `hdfs oiv` to inspect FsImages.

This setup makes the NameNode highly reliable for petabyte-scale data, balancing performance and durability. For production, always enable HA to avoid downtime.
