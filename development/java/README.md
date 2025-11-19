# Hadoop Java Cheat Sheet

This cheat sheet covers key concepts, APIs, and code snippets for working with Hadoop using Java, focusing on HDFS, MapReduce, and common configurations.

## 1. Hadoop Core Concepts
- **HDFS**: Hadoop Distributed File System, for storing large datasets.
- **MapReduce**: Distributed data processing framework.
- **YARN**: Resource management and job scheduling.
- **Key Classes**:
  - `Configuration`: Manages Hadoop configurations.
  - `FileSystem`: Interacts with HDFS.
  - `Job`: Configures and submits MapReduce jobs.
  - `Mapper` and `Reducer`: Core classes for MapReduce logic.

## 2. Setting Up Hadoop Environment
### Maven Dependencies
```xml
<dependencies>
    <dependency>
        <groupId>org.apache.hadoop</groupId>
        <artifactId>hadoop-common</artifactId>
        <version>3.3.6</version>
    </dependency>
    <dependency>
        <groupId>org.apache.hadoop</groupId>
        <artifactId>hadoop-mapreduce-client-core</artifactId>
        <version>3.3.6</version>
    </dependency>
</dependencies>
```

### Basic Configuration
```java
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.FileSystem;

Configuration conf = new Configuration();
conf.set("fs.defaultFS", "hdfs://localhost:9000"); // Set HDFS URI
FileSystem fs = FileSystem.get(conf);
```

## 3. HDFS Operations
### Reading a File
```java
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.fs.FSDataInputStream;

Path path = new Path("/path/to/file.txt");
FSDataInputStream in = fs.open(path);
BufferedReader reader = new BufferedReader(new InputStreamReader(in));
String line;
while ((line = reader.readLine()) != null) {
    System.out.println(line);
}
reader.close();
```

### Writing a File
```java
import org.apache.hadoop.fs.FSDataOutputStream;

Path path = new Path("/path/to/output.txt");
FSDataOutputStream out = fs.create(path);
out.writeBytes("Hello, Hadoop!".getBytes());
out.close();
```

### Listing Files
```java
import org.apache.hadoop.fs.FileStatus;

FileStatus[] status = fs.listStatus(new Path("/path/to/dir"));
for (FileStatus file : status) {
    System.out.println(file.getPath().getName());
}
```

### Deleting a File/Directory
```java
fs.delete(new Path("/path/to/file.txt"), true); // true for recursive delete
```

## 4. MapReduce Programming
### Basic MapReduce Job Structure
```java
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class WordCount {
    // Mapper Class
    public static class WordCountMapper extends Mapper<LongWritable, Text, Text, IntWritable> {
        private final static IntWritable one = new IntWritable(1);
        private Text word = new Text();

        @Override
        protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
            String[] words = value.toString().split("\\s+");
            for (String w : words) {
                word.set(w);
                context.write(word, one);
            }
        }
    }

    // Reducer Class
    public static class WordCountReducer extends Reducer<Text, IntWritable, Text, IntWritable> {
        private IntWritable result = new IntWritable();

        @Override
        protected void reduce(Text key, Iterable<IntWritable> values, Context context) throws IOException, InterruptedException {
            int sum = 0;
            for (IntWritable val : values) {
                sum += val.get();
            }
            result.set(sum);
            context.write(key, result);
        }
    }

    // Main Method
    public static void main(String[] args) throws Exception {
        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "WordCount");
        job.setJarByClass(WordCount.class);
        job.setMapperClass(WordCountMapper.class);
        job.setCombinerClass(WordCountReducer.class);
        job.setReducerClass(WordCountReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);
        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
```

### Common MapReduce Configurations
```java
job.setNumReduceTasks(2); // Set number of reducers
job.setInputFormatClass(TextInputFormat.class); // Input format
job.setOutputFormatClass(TextOutputFormat.class); // Output format
job.setMapOutputKeyClass(Text.class); // Mapper output key type
job.setMapOutputValueClass(IntWritable.class); // Mapper output value type
```

## 5. Common Writable Types
- `Text`: String equivalent.
- `IntWritable`: Integer equivalent.
- `LongWritable`: Long equivalent.
- `FloatWritable`: Float equivalent.
- `DoubleWritable`: Double equivalent.
- `NullWritable`: Placeholder for null values.

## 6. Combiner
A combiner reduces intermediate data before sending to the reducer.
```java
job.setCombinerClass(WordCountReducer.class); // Use reducer as combiner
```

## 7. Partitioner
Controls how map output is distributed to reducers.
```java
public class CustomPartitioner extends Partitioner<Text, IntWritable> {
    @Override
    public int getPartition(Text key, IntWritable value, int numPartitions) {
        return Math.abs(key.hashCode() % numPartitions);
    }
}
job.setPartitionerClass(CustomPartitioner.class);
```

## 8. Chaining MapReduce Jobs
```java
Job job1 = Job.getInstance(conf, "Job1");
// Configure job1
job1.waitForCompletion(true);

Job job2 = Job.getInstance(conf, "Job2");
// Configure job2
job2.waitForCompletion(true);
```

## 9. Debugging Tips
- Check logs in Hadoop’s web UI (default: `http://localhost:9870` for HDFS, `http://localhost:8088` for YARN).
- Use `context.write` sparingly to avoid excessive I/O.
- Test locally with small datasets before running on a cluster.

## 10. Common Exceptions
- **IOException**: Check HDFS connectivity and permissions.
- **ClassNotFoundException**: Ensure `job.setJarByClass` is set correctly.
- **IllegalArgumentException**: Verify input/output paths exist.

## 11. Best Practices
- Use combiners to reduce network shuffle.
- Set appropriate number of reducers based on data size.
- Avoid complex logic in mappers/reducers for better performance.
- Use counters for debugging:
  ```java
  context.getCounter("MyGroup", "MyCounter").increment(1);
  ```

## 12. Running a Job
```bash
hadoop jar myapp.jar WordCount /input /output
```
