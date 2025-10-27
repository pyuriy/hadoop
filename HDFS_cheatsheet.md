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
