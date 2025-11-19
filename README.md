# Hadoop Cheat Sheet

## Overview
Hadoop is an open-source framework for distributed storage and processing of large datasets across clusters. Key components include:

| Component | Description |
|-----------|-------------|
| **Hadoop Common** | Java libraries and utilities for other modules. |
| **HDFS (Hadoop Distributed File System)** | Scalable, fault-tolerant file system for high-throughput data access. |
| **YARN (Yet Another Resource Negotiator)** | Manages cluster resources and job scheduling. |
| **MapReduce** | Framework for parallel processing of large datasets via map and reduce tasks. |

**Ecosystem Tools**:
- **Hive**: Data warehousing and SQL-like querying on Hadoop.
- **Pig**: Scripting for data flows and MapReduce jobs.
- **Spark**: In-memory cluster computing (faster alternative to MapReduce).
- **HBase**: NoSQL database for real-time read/write access.
- **Sqoop**: Transfers data between Hadoop and relational databases.
- **Flume**: Collects and aggregates streaming data.
- **Oozie**: Workflow scheduler for Hadoop jobs.

## HDFS Commands
HDFS commands use `hdfs dfs` prefix (or `hadoop fs`). Examples assume default HDFS paths.

### Listing Files/Directories
| Command | Description | Example |
|---------|-------------|---------|
| `hdfs dfs -ls <path>` | List files/directories. | `hdfs dfs -ls /` |
| `hdfs dfs -ls -R <path>` | Recursive list. | `hdfs dfs -ls -R /user` |
| `hdfs dfs -ls -h <path>` | Human-readable sizes. | `hdfs dfs -ls -h /tmp` |
| `hdfs dfs -ls -d <path>` | Treat directory as file. | `hdfs dfs -ls -d /tmp` |
| `hdfs dfs -count [-q] <path>` | Count directories, files, bytes. | `hdfs dfs -count /`  |

### Reading/Writing Files
| Command | Description | Example |
|---------|-------------|---------|
| `hdfs dfs -cat <path>` | Display file content to stdout. | `hdfs dfs -cat /file.txt` |
| `hdfs dfs -text <path>` | Output in text format (e.g., for zipped files). | `hdfs dfs -text /file.zip` |
| `hdfs dfs -tail [-f] <path>` | Show last kilobyte. | `hdfs dfs -tail /file.txt` |
| `hdfs dfs -appendToFile <local> <hdfs>` | Append local file to HDFS file. | `hdfs dfs -appendToFile local.txt /file.txt`  |

### Upload/Download (Local ↔ HDFS)
| Command | Description | Example |
|---------|-------------|---------|
| `hdfs dfs -put <local> <hdfs>` | Upload local file(s). | `hdfs dfs -put local.txt /` |
| `hdfs dfs -put -p <local> <hdfs>` | Upload preserving metadata. | `hdfs dfs -put -p local.txt /` |
| `hdfs dfs -put -f <local> <hdfs>` | Upload and overwrite. | `hdfs dfs -put -f local.txt /` |
| `hdfs dfs -get <hdfs> <local>` | Download HDFS file. | `hdfs dfs -get /file.txt local.txt` |
| `hdfs dfs -get -p <hdfs> <local>` | Download preserving metadata. | `hdfs dfs -get -p /file.txt local.txt` |
| `hdfs dfs -getmerge <hdfs_dir> <local>` | Merge and download directory. | `hdfs dfs -getmerge /dir/ local.txt` |
| `hdfs dfs -copyFromLocal <local> <hdfs>` | Copy from local (alias for put). | `hdfs dfs -copyFromLocal local.txt /` |
| `hdfs dfs -copyToLocal <hdfs> <local>` | Copy to local (alias for get). | `hdfs dfs -copyToLocal /file.txt local.txt` |
| `hdfs dfs -moveFromLocal <local> <hdfs>` | Move from local (deletes source). | `hdfs dfs -moveFromLocal local.txt /`  |

### File/Directory Management
| Command | Description | Example |
|---------|-------------|---------|
| `hdfs dfs -cp <src> <dest>` | Copy within HDFS. | `hdfs dfs -cp /file1 /dir/` |
| `hdfs dfs -cp -p <src> <dest>` | Copy preserving metadata. | `hdfs dfs -cp -p /file1 /dir/` |
| `hdfs dfs -mv <src> <dest>` | Move within HDFS. | `hdfs dfs -mv /file1 /dir/` |
| `hdfs dfs -rm <path>` | Delete file. | `hdfs dfs -rm /file.txt` |
| `hdfs dfs -rm -r <path>` | Delete directory recursively. | `hdfs dfs -rm -r /dir` |
| `hdfs dfs -rm -skipTrash <path>` | Delete bypassing trash. | `hdfs dfs -rm -skipTrash /file.txt` |
| `hdfs dfs -mkdir <path>` | Create directory. | `hdfs dfs -mkdir /newdir` |
| `hdfs dfs -mkdir -p <path>` | Create parent directories if needed. | `hdfs dfs -mkdir -p /dir/subdir` |
| `hdfs dfs -touchz <path>` | Create empty file. | `hdfs dfs -touchz /empty.txt` |
| `hdfs dfs -expunge` | Empty trash. | `hdfs dfs -expunge`  |

### Permissions & Ownership
| Command | Description | Example |
|---------|-------------|---------|
| `hdfs dfs -chmod <mode> <path>` | Change permissions. | `hdfs dfs -chmod 755 /file.txt` |
| `hdfs dfs -chmod -R <mode> <path>` | Recursive permissions. | `hdfs dfs -chmod -R 755 /dir` |
| `hdfs dfs -chown <owner:group> <path>` | Change owner/group. | `hdfs dfs -chown user:group /file.txt` |
| `hdfs dfs -chown -R <owner:group> <path>` | Recursive ownership. | `hdfs dfs -chown -R user:group /dir` |
| `hdfs dfs -chgrp <group> <path>` | Change group. | `hdfs dfs -chgrp group /file.txt`  |

### Space & Info
| Command | Description | Example |
|---------|-------------|---------|
| `hdfs dfs -du [-s] [-h] <path>` | Disk usage (bytes or human-readable). | `hdfs dfs -du -h /dir` |
| `hdfs dfs -df [-h] <path>` | Filesystem disk usage. | `hdfs dfs -df -h /` |
| `hdfs dfs -stat <path>` | File/directory stats. | `hdfs dfs -stat /file.txt` |
| `hdfs dfs -setrep <rep> [-R] <path>` | Set replication factor. | `hdfs dfs -setrep 3 /file.txt` |
| `hdfs dfs -checksum <path>` | Display checksum. | `hdfs dfs -checksum /file.txt`  |

## YARN Commands
| Command | Description | Example |
|---------|-------------|---------|
| `yarn` | Show YARN help. | `yarn` |
| `yarn application -list` | List applications. | `yarn application -list` |
| `yarn node -list` | List nodes. | `yarn node -list` |
| `yarn queue -status <queue>` | Queue status. | `yarn queue -status default`  |

## Administration Commands
| Command | Description | Example |
|---------|-------------|---------|
| `hdfs balancer -threshold <val>` | Balance data across nodes. | `hdfs balancer -threshold 10` |
| `hdfs dfsadmin -report` | Filesystem report. | `hdfs dfsadmin -report` |
| `hdfs dfsadmin -safemode leave` | Exit safe mode. | `hdfs dfsadmin -safemode leave` |
| `hdfs fsck /` | Filesystem check. | `hdfs fsck /` |
| `hadoop version` | Print Hadoop version. | `hadoop version`  |

## Quick Tips
- **Safe Mode**: Enter with `hdfs dfsadmin -safemode enter`; useful during startup.
- **Replication**: Default is 3; adjust with `-setrep`.
- **Trash**: Files go to trash unless `-skipTrash`; empty with `-expunge`.
- For MapReduce jobs: Submit with `hadoop jar <jar> <class> <input> <output>`.

This cheat sheet is compiled for quick reference. For full docs, visit Apache Hadoop official site.
