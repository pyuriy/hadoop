# Comprehensive Hadoop Lab Guide

This hands-on lab guide provides a step-by-step tutorial for setting up and working with Hadoop in a single-node (pseudo-distributed) environment. It's designed for beginners with basic Linux and Java knowledge. We'll cover installation, HDFS operations, a MapReduce example, and an introduction to Hive. Use Ubuntu 20.04+ for best compatibility. All commands assume you're running as a non-root user (e.g., `hadoop`).

**Prerequisites:**
- Ubuntu Linux (or compatible).
- Basic familiarity with terminal commands.
- At least 4GB RAM and 10GB free disk space.
- Internet for downloads.

**Estimated Time:** 2-3 hours.

## Lab 1: Single-Node Hadoop Setup

We'll install Hadoop 3.3.6 (stable as of 2025) in pseudo-distributed mode, simulating a cluster on one machine.

### Step 1: Install Dependencies
Update packages and install Java 8 and SSH:
```
sudo apt update
sudo apt install openjdk-8-jdk ssh rsync
```
Verify Java:
```
java -version
```
Output should show OpenJDK 8.

### Step 2: Create Hadoop User and SSH Setup
Create a dedicated user:
```
sudo adduser hadoop
sudo usermod -aG sudo hadoop
su - hadoop
```
Set up passwordless SSH:
```
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
ssh localhost  # Test (accept host key if prompted)
```

### Step 3: Download and Extract Hadoop
```
cd ~
wget https://archive.apache.org/dist/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
tar -xvzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 hadoop
```
Set environment variables in `~/.bashrc`:
```
nano ~/.bashrc
```
Add:
```
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/home/hadoop/hadoop
export HADOOP_INSTALL=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export HADOOP_YARN_HOME=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"
```
Apply:
```
source ~/.bashrc
```
Edit `$HADOOP_HOME/etc/hadoop/hadoop-env.sh`:
```
nano $HADOOP_HOME/etc/hadoop/hadoop-env.sh
```
Add/uncomment:
```
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
```

### Step 4: Configure Hadoop Files
Create directories:
```
mkdir -p ~/hadoopdata/hdfs/{namenode,datanode}
```
Edit `$HADOOP_HOME/etc/hadoop/core-site.xml`:
```
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
```
Edit `$HADOOP_HOME/etc/hadoop/hdfs-site.xml`:
```
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///home/hadoop/hadoopdata/hdfs/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///home/hadoop/hadoopdata/hdfs/datanode</value>
    </property>
</configuration>
```
Edit `$HADOOP_HOME/etc/hadoop/mapred-site.xml`:
```
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
```
Edit `$HADOOP_HOME/etc/hadoop/yarn-site.xml`:
```
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>localhost</value>
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value>
    </property>
</configuration>
```

### Step 5: Start and Verify
Format HDFS:
```
hdfs namenode -format
```
Start services:
```
start-dfs.sh
start-yarn.sh
```
Verify:
- NameNode UI: Open `http://localhost:9870` in browser.
- ResourceManager UI: `http://localhost:8088`.
- Check processes: `jps` (should show NameNode, DataNode, ResourceManager, NodeManager).

**Troubleshooting:**
- "JAVA_HOME not set": Double-check `hadoop-env.sh`.
- SSH issues: Ensure `sshd` is running (`sudo service ssh start`).
- Port conflicts: Kill processes on 9000/9870/8088.

Stop services: `stop-yarn.sh && stop-dfs.sh`.

## Lab 2: HDFS Operations

HDFS is Hadoop's distributed file system. We'll practice basic CRUD operations.

### Step 1: Create User Directory
```
hdfs dfs -mkdir -p /user/hadoop
hdfs dfs -ls /
```

### Step 2: Upload and Inspect Files
Create a local test file:
```
echo "Hello Hadoop World" > local.txt
```
Upload:
```
hdfs dfs -put local.txt /user/hadoop/
hdfs dfs -ls /user/hadoop/
hdfs dfs -cat /user/hadoop/local.txt
hdfs dfs -du -h /user/hadoop/  # Disk usage
```

### Step 3: Download and Manage
Download:
```
hdfs dfs -get /user/hadoop/local.txt downloaded.txt
cat downloaded.txt
```
Copy within HDFS:
```
hdfs dfs -cp /user/hadoop/local.txt /user/hadoop/copy.txt
```
Delete:
```
hdfs dfs -rm /user/hadoop/copy.txt
hdfs dfs -rm -r /user/hadoop/local.txt  # Recursive for dirs
```

### Exercise 2.1
1. Create a directory `/user/hadoop/lab` and upload 3 local text files (e.g., with sample data like words or logs).
2. List recursively: `hdfs dfs -ls -R /user/hadoop/lab`.
3. Set replication to 1: `hdfs dfs -setrep -R 1 /user/hadoop/lab`.
4. Check filesystem health: `hdfs fsck / -files -blocks -locations`.

**Expected Output:** Files listed with sizes; no corruption in fsck.

## Lab 3: MapReduce WordCount Example

MapReduce processes data in parallel. We'll implement and run a WordCount job to count word frequencies.

### Step 1: Prepare Input
Create input directory and sample files:
```
hdfs dfs -mkdir /user/hadoop/input
echo "Hello Hadoop MapReduce Hello World" > file1.txt
echo "Hadoop is distributed computing framework" > file2.txt
hdfs dfs -put file1.txt file2.txt /user/hadoop/input/
hdfs dfs -ls /user/hadoop/input/
```

### Step 2: Create Java Code
Create `WordCount.java` in `$HADOOP_HOME`:
```
nano $HADOOP_HOME/WordCount.java
```
Paste:
```java
import java.io.IOException;
import java.util.StringTokenizer;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class WordCount {

  public static class TokenizerMapper
       extends Mapper<Object, Text, Text, IntWritable>{

    private final static IntWritable one = new IntWritable(1);
    private Text word = new Text();

    public void map(Object key, Text value, Context context
                    ) throws IOException, InterruptedException {
      StringTokenizer itr = new StringTokenizer(value.toString());
      while (itr.hasMoreTokens()) {
        word.set(itr.nextToken());
        context.write(word, one);
      }
    }
  }

  public static class IntSumReducer
       extends Reducer<Text,IntWritable,Text,IntWritable> {
    private IntWritable result = new IntWritable();

    public void reduce(Text key, Iterable<IntWritable> values,
                       Context context
                       ) throws IOException, InterruptedException {
      int sum = 0;
      for (IntWritable val : values) {
        sum += val.get();
      }
      result.set(sum);
      context.write(key, result);
    }
  }

  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();
    Job job = Job.getInstance(conf, "word count");
    job.setJarByClass(WordCount.class);
    job.setMapperClass(TokenizerMapper.class);
    job.setCombinerClass(IntSumReducer.class);
    job.setReducerClass(IntSumReducer.class);
    job.setOutputKeyClass(Text.class);
    job.setOutputValueClass(IntWritable.class);
    FileInputFormat.addInputPath(job, new Path(args[0]));
    FileOutputFormat.setOutputPath(job, new Path(args[1]));
    System.exit(job.waitForCompletion(true) ? 0 : 1);
  }
}
```
Compile:
```
cd $HADOOP_HOME
hadoop com.sun.tools.javac.Main WordCount.java
jar cf wc.jar WordCount*.class
```

### Step 3: Run the Job
```
hadoop jar wc.jar WordCount /user/hadoop/input /user/hadoop/output
```
Monitor in YARN UI (`http://localhost:8088`).

### Step 4: View Results
```
hdfs dfs -cat /user/hadoop/output/part-r-00000
```
Expected output (sorted words with counts):
```
Hadoop  2
Hello   2
MapReduce   1
World   1
computing   1
distributed 1
framework   1
is  1

### Exercise 3.1
1. Add more files to input with varied text.
2. Run the job; observe combiner reducing data transfer.
3. Modify mapper to lowercase words (use `word.set(itr.nextToken().toLowerCase())`); recompile and rerun.

**Troubleshooting:** If "class not found," ensure JAR includes all classes. Clean output dir: `hdfs dfs -rm -r /user/hadoop/output`.

## Lab 4: Introduction to Hive

Hive provides SQL-like querying on HDFS data. We'll set up Hive 3.1.3 and run a basic query.

### Step 1: Install Hive
Download:
```
cd ~
wget https://archive.apache.org/dist/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz
tar -xvzf apache-hive-3.1.3-bin.tar.gz
mv apache-hive-3.1.3-bin hive
```
Set env in `~/.bashrc`:
```
export HIVE_HOME=/home/hadoop/hive
export PATH=$PATH:$HIVE_HOME/bin
```
Source: `source ~/.bashrc`.

### Step 2: Configure Hive
Initialize metastore (Derby DB for lab):
```
$HIVE_HOME/bin/schematool -dbType derby -initSchema
```
Edit `$HIVE_HOME/conf/hive-site.xml`:
```
<configuration>
    <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:derby:;databaseName=/home/hadoop/hive/metastore_db;create=true</value>
    </property>
    <property>
        <name>hive.execution.engine</name>
        <value>mr</value>
    </property>
</configuration>
```

### Step 3: Start Hive and Create Table
Start Hadoop services if stopped.
Launch Hive CLI:
```
hive
```
In Hive shell:
```
CREATE DATABASE labdb;
USE labdb;
CREATE TABLE words (word STRING) ROW FORMAT DELIMITED FIELDS TERMINATED BY ' ' STORED AS TEXTFILE;
LOAD DATA INPATH '/user/hadoop/input/*' INTO TABLE words;
SELECT word, COUNT(*) as count FROM words GROUP BY word;
```
Exit: `exit;`.

Expected: Word counts similar to MapReduce.

### Exercise 4.1
1. Create a table for CSV data: Upload a sample CSV to HDFS, load into table.
2. Run aggregate queries (e.g., AVG if numeric data).

**Troubleshooting:** Derby lock issues? Delete `metastore_db` and reinitialize.

## Advanced Exercises and Projects
1. **YARN Queue Management:** Configure multiple queues in `yarn-site.xml`; submit jobs to specific queues.
2. **Pig Script:** Install Pig, write a simple script to filter/join data from HDFS.
3. **Project: Log Analysis** – Process web logs with MapReduce to find top IPs; query with Hive.

For more, explore Cloudera/Hortonworks sandboxes or AWS EMR for cloud labs. Practice on datasets from Kaggle.

This lab builds foundational skills. Experiment and refer to the cheat sheet for commands!
