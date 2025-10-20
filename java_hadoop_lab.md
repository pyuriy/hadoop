### Comprehensive Hadoop Java Practice Lab

This lab provides a hands-on, step-by-step guide to working with Hadoop using Java for MapReduce programming. It assumes basic Java knowledge and focuses on practical exercises to build and run MapReduce jobs. We'll use the Hadoop MapReduce framework to process large datasets, starting with setup and progressing to advanced exercises.

The lab is divided into sections: **Setup**, **Core Concepts**, **Basic Exercises**, **Advanced Exercises**, and **Troubleshooting**. All code examples use the modern Hadoop API (post-0.20, e.g., Hadoop 3.x). We'll test on a pseudo-distributed (single-node) cluster for simplicity, but concepts scale to full clusters.

#### Section 1: Environment Setup
To run Hadoop MapReduce jobs, you need a Java Development Kit (JDK 8 or 11) and Hadoop installed. We'll use a pseudo-distributed mode where Hadoop runs on your local machine, simulating a cluster.

1. **Install Java**:
   - Download and install JDK 8 or 11 from Oracle or OpenJDK.
   - Set `JAVA_HOME` in your shell profile (e.g., `~/.bashrc`):
     ```
     export JAVA_HOME=/path/to/your/jdk
     export PATH=$PATH:$JAVA_HOME/bin
     ```
   - Verify: `java -version`.

2. **Install Hadoop**:
   - Download the latest stable Hadoop (e.g., 3.4.0) from the Apache Hadoop website.
https://www.apache.org/dyn/closer.cgi/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz
   - Extract to a directory, e.g., `/opt/hadoop`.
   - Set environment variables in `~/.bashrc`:
     ```
     export HADOOP_HOME=/opt/hadoop
     export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
     export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
     ```
   - Verify: `hadoop version`.

3. **Configure Pseudo-Distributed Mode**:
   - Edit `$HADOOP_HOME/etc/hadoop/core-site.xml`:
     ```xml
     <configuration>
         <property>
             <name>fs.defaultFS</name>
             <value>hdfs://localhost:9000</value>
         </property>
     </configuration>
     ```
   - Edit `$HADOOP_HOME/etc/hadoop/hdfs-site.xml`:
     ```xml
     <configuration>
         <property>
             <name>dfs.replication</name>
             <value>1</value>
         </property>
         <property>
             <name>dfs.namenode.name.dir</name>
             <value>file:///opt/hadoopdata/hdfs/namenode</value>
         </property>
         <property>
             <name>dfs.datanode.data.dir</name>
             <value>file:///opt/hadoopdata/hdfs/datanode</value>
         </property>
     </configuration>
     ```
   - Edit `$HADOOP_HOME/etc/hadoop/mapred-site.xml`:
     ```xml
     <configuration>
         <property>
             <name>mapreduce.framework.name</name>
             <value>yarn</value>
         </property>
     </configuration>
     ```
   - Edit `$HADOOP_HOME/etc/hadoop/yarn-site.xml`:
     ```xml
     <configuration>
         <property>
             <name>yarn.nodemanager.aux-services</name>
             <value>mapreduce_shuffle</value>
         </property>
     </configuration>
     ```
   - Format HDFS: `hdfs namenode -format`.
   - Start services: `start-dfs.sh && start-yarn.sh`.
   - Verify: Access NameNode UI at `http://localhost:9870` and ResourceManager at `http://localhost:8088`.

4. **Create a Project Directory**:
   - Make a directory: `mkdir ~/hadoop-lab && cd ~/hadoop-lab`.
   - Create subdirs: `mkdir input output src`.
   - Add sample input data to `input/` (e.g., create `input/file1.txt` with content: "Hello Hadoop Hello World" and `input/file2.txt` with "World Hadoop MapReduce").

5. **Compile and Run Jobs**:
   - Compile Java code: `javac -classpath $HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/mapreduce/* -d classes src/YourJob.java`.
   - Create JAR: `jar -cvf yourjob.jar -C classes/ .`.
   - Run: `hadoop jar yourjob.jar YourJob /input /output`.

#### Section 2: Core Concepts
- **MapReduce Overview**: MapReduce processes data in two phases: **Map** (processes input key-value pairs, emits intermediate pairs) and **Reduce** (aggregates intermediate pairs by key). Hadoop handles distribution, fault tolerance, and shuffling.
- **Key Classes**:
  - `Mapper<KEYIN, VALUEIN, KEYOUT, VALUEOUT>`: Processes input.
  - `Reducer<KEYIN, VALUEIN, KEYOUT, VALUEOUT>`: Aggregates.
  - `Job`: Configures the job.
  - `Text`, `IntWritable`: Common I/O types.
- Data flow: Input → Split → Map → Shuffle/Sort → Reduce → Output.

#### Section 3: Basic Exercises
Start with WordCount, the canonical example.

**Exercise 1: WordCount (Count Word Occurrences)**
- Goal: Count how many times each word appears across input files.
- Code (`src/WordCount.java`):
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
      public static class TokenizerMapper extends Mapper<Object, Text, Text, IntWritable> {
          private final static IntWritable one = new IntWritable(1);
          private Text word = new Text();

          public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
              StringTokenizer itr = new StringTokenizer(value.toString());
              while (itr.hasMoreTokens()) {
                  word.set(itr.nextToken());
                  context.write(word, one);
              }
          }
      }

      public static class IntSumReducer extends Reducer<Text, IntWritable, Text, IntWritable> {
          private IntWritable result = new IntWritable();

          public void reduce(Text key, Iterable<IntWritable> values, Context context) throws IOException, InterruptedException {
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
- Steps:
  1. Compile: `javac -classpath $HADOOP_HOME/share/hadoop/common/hadoop-common-*.jar:$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-core-*.jar -d classes src/WordCount.java`.
  2. JAR: `jar -cvf wordcount.jar -C classes/ .`.
  3. Put input to HDFS: `hdfs dfs -put input/* /input`.
  4. Run: `hadoop jar wordcount.jar WordCount /input /output`.
  5. View output: `hdfs dfs -cat /output/part-r-00000`.
- Expected Output (for sample input): Lines like "Hadoop	2" or "Hello	1".
- Learning: Mapper tokenizes text; Reducer sums counts. Combiner optimizes by running locally on each mapper.

**Exercise 2: Inverted Index (Document-Word Mapping)**
- Goal: For each word, list documents containing it (e.g., for search indexing).
- Modify WordCount to emit <word, doc_id> pairs.
- Code Snippet Changes (in Mapper):
  ```java
  // In map(): Use file split info for doc_id
  private final static String docId = "doc_" + context.getTaskAttemptID().getTaskID().getId(); // Simple doc ID
  // Emit: context.write(word, new Text(docId));
  ```
- Reducer: Collect list of doc IDs per word (use `Text` for comma-separated list).
- Run similarly; output: "Hadoop	doc_0,doc_1".

#### Section 4: Advanced Exercises
Build on basics for real-world scenarios.

**Exercise 3: Max Temperature Per Year**
- Goal: From weather data (format: year,month,day,temp), find max temp per year.
- Sample Input (`input/weather.txt`): "2000,1,1,35\n2000,1,2,40\n2001,1,1,38".
- Mapper: Emit <year, temp>.
- Reducer: Emit max temp per year.
- Code (`src/MaxTemp.java`):
  ```java
  // Mapper
  public class MaxTempMapper extends Mapper<LongWritable, Text, Text, IntWritable> {
      private Text year = new Text();
      public void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
          String[] line = value.toString().split(",");
          if (line.length == 4) {
              year.set(line[0]);
              context.write(year, new IntWritable(Integer.parseInt(line[3])));
          }
      }
  }

  // Reducer
  public class MaxTempReducer extends Reducer<Text, IntWritable, Text, IntWritable> {
      private IntWritable maxTemp = new IntWritable();
      public void reduce(Text key, Iterable<IntWritable> values, Context context) throws IOException, InterruptedException {
          int max = Integer.MIN_VALUE;
          for (IntWritable val : values) {
              max = Math.max(max, val.get());
          }
          maxTemp.set(max);
          context.write(key, maxTemp);
      }
  }

  // Main: Similar to WordCount, set classes accordingly.
  ```
- Run and view: Output like "2000	40".

**Exercise 4: Top-K Claims (Secondary Sort)**
- Goal: From patent data (format: patent_id,claims), find top K patents by claims count.
- Use secondary sort for top-K; input sample: "123,50\n456,100".
- Mapper: Emit <claims (reversed for sort), patent_id>.
- Reducer: Collect top K.
- Hint: Implement `WritableComparable` for custom key; use `TopKReducer` with priority queue.

**Exercise 5: Inner Join on Student Data**
- Goal: Join two tables on student ID (e.g., students.txt: "ID,Name"; grades.txt: "ID,Grade").
- Mapper: Tag records (e.g., emit <ID, "S:Name"> or <ID, "G:Grade">).
- Reducer: Join tags per ID.
- Output: "ID,Name,Grade".

#### Section 5: Troubleshooting and Best Practices
| Issue | Solution |
|-------|----------|
| ClassNotFoundException | Ensure classpath includes all Hadoop JARs: `$HADOOP_CLASSPATH=$HADOOP_HOME/share/hadoop/*`. |
| Output dir exists | Delete: `hdfs dfs -rm -r /output`. |
| Job fails (e.g., 66% hang) | Normal in local mode; check logs: `yarn logs -applicationId <app_id>`. |
| OutOfMemory | Increase heap: Add `-Xmx2g` to `mapreduce.map.java.opts` in `mapred-site.xml`. |

- **Performance Tips**: Use combiners for aggregation; compress intermediates (`mapreduce.map.output.compress=true`).
- **Extensions**: Integrate with HBase for storage or Hive for SQL-like queries.
- **Resources**: Experiment with larger datasets from UCI ML Repo (e.g., weather logs). For full code repos, check GitHub for "hadoop-mapreduce-examples".

This lab builds practical skills—run each exercise and tweak for variations. If issues arise, check Hadoop logs in `/opt/hadoop/logs`.
