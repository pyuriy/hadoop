# Comprehensive Hands-On Lab: Apache Cassandra

This lab guide provides a step-by-step, hands-on introduction to Apache Cassandra (version 5.0, the latest GA release as of October 2025). It covers setup, core concepts, data modeling, queries, advanced features, and practical exercises. Designed for beginners to intermediate users, it assumes basic command-line familiarity. We'll use Docker for a quick, isolated environment—no local installation required.

**Estimated Time:** 2-3 hours  
**Tools Needed:** Docker (install from [docker.com](https://www.docker.com))  
**Environment:** Single-node cluster for simplicity; extendable to multi-node.

## Section 1: Installation and Setup

### Step 1.1: Pull and Run Cassandra Container
1. Open a terminal and pull the latest Cassandra image:
   ```
   docker pull cassandra:5.0
   ```
   
2. Create a Docker network for better isolation (optional but recommended):
   ```
   docker network create cassandra-net
   ```

3. Run the container in detached mode, mapping port 9042:
   ```
   docker run --rm -d --name cassandra-db --hostname cassandra --network cassandra-net -p 9042:9042 cassandra:5.0
   ```
   - `--rm`: Auto-remove on stop.
   - Wait 30-60 seconds for initialization (Cassandra logs to console via `docker logs cassandra-db`).

### Step 1.2: Access CQL Shell (cqlsh)
1. Install cqlsh if needed (or use Docker's version):
   - On Ubuntu/Mac: `pip install cqlsh` (requires Python 3).
   - Or exec into the container:
     ```
     docker exec -it cassandra-db cqlsh cassandra 9042
     ```
     This opens the interactive CQL shell.

2. Verify connection:
   ```
   SHOW VERSION;
   ```
   Expected: `5.0.x` (or similar).

3. Exit shell: `exit;`

### Step 1.3: Cleanup (End of Lab)
```
docker stop cassandra-db
docker network rm cassandra-net
```

## Section 2: Basic Operations

We'll create a keyspace, table, and perform CRUD operations using a simple "users" dataset.

### Step 2.1: Create and Use a Keyspace
In cqlsh:
```
CREATE KEYSPACE IF NOT EXISTS lab_keyspace 
WITH REPLICATION = {'class': 'SimpleStrategy', 'replication_factor': 1};
USE lab_keyspace;
```
- **SimpleStrategy**: For single-DC testing (use NetworkTopologyStrategy for production).

### Step 2.2: Create a Table
```
CREATE TABLE users (
    user_id UUID PRIMARY KEY,
    username TEXT,
    email TEXT,
    age INT
);
```
- **PRIMARY KEY**: `user_id` is the partition key (distributes data across nodes).

### Step 2.3: Insert Data
```
INSERT INTO users (user_id, username, email, age) VALUES (uuid(), 'alice', 'alice@example.com', 28);
INSERT INTO users (user_id, username, email, age) VALUES (uuid(), 'bob', 'bob@example.com', 35);
INSERT INTO users (user_id, username, email, age) VALUES (uuid(), 'charlie', 'charlie@example.com', 42);
```

### Step 2.4: Read Data
```
SELECT * FROM users;
```
Expected output:
```
 user_id                                   | age | email              | username
--------------------------------------+-----+--------------------+----------
 123e4567-e89b-12d3-a456-426614174000 |  28 | alice@example.com  |   alice
 ... (truncated)
```

### Step 2.5: Update and Delete
```
-- Update (Cassandra uses INSERT for upserts)
INSERT INTO users (user_id, age) VALUES (123e4567-e89b-12d3-a456-426614174000, 29);

-- Delete
DELETE FROM users WHERE user_id = 123e4567-e89b-12d3-a456-426614174000;
SELECT * FROM users;  -- Verify deletion
```

## Section 3: Data Modeling

Cassandra is denormalized; design for queries (not normalization).

### Step 3.1: Table with Clustering Key
Clustering columns sort data within partitions.
```
CREATE TABLE posts (
    user_id UUID,
    post_id TIMEUUID,
    title TEXT,
    content TEXT,
    created_at TIMESTAMP,
    PRIMARY KEY ((user_id), post_id)  -- user_id: partition; post_id: clustering (auto-sorts by time)
) WITH CLUSTERING ORDER BY (post_id DESC);
```
- Insert:
  ```
  INSERT INTO posts (user_id, post_id, title, content, created_at) 
  VALUES (uuid(), now(), 'First Post', 'Hello Cassandra!', toTimestamp(now()));
  INSERT INTO posts (user_id, post_id, title, content, created_at) 
  VALUES (uuid(), now(), 'Second Post', 'Learning CQL', toTimestamp(now()));
  ```
- Query (latest first):
  ```
  SELECT * FROM posts WHERE user_id = <your_user_id>;
  ```

### Step 3.2: Static Columns
For data shared across rows in a partition.
```
CREATE TABLE groups (
    group_id INT,
    group_name TEXT STATIC,
    username TEXT,
    age INT,
    PRIMARY KEY ((group_id), username)
);
INSERT INTO groups (group_id, group_name, username, age) VALUES (1, 'DevOps', 'dev1', 30);
INSERT INTO groups (group_id, username, age) VALUES (1, 'dev2', 25);  -- group_name auto-applies
SELECT * FROM groups WHERE group_id = 1;
```

## Section 4: Advanced Features

### Step 4.1: Collections (Lists, Sets, Maps)
```
CREATE TABLE profiles (
    user_id UUID PRIMARY KEY,
    hobbies LIST<TEXT>,
    tags SET<TEXT>,
    metadata MAP<TEXT, TEXT>
);
INSERT INTO profiles (user_id, hobbies, tags, metadata) 
VALUES (uuid(), ['reading', 'coding'], {'tech', 'nosql'}, {'version': '1.0'});
SELECT hobbies, tags FROM profiles;
-- Query collection: SELECT * FROM profiles WHERE hobbies CONTAINS 'coding';
```

### Step 4.2: User-Defined Types (UDTs)
```
CREATE TYPE address (
    street TEXT,
    city TEXT,
    zip INT
);
CREATE TABLE employees (
    emp_id UUID PRIMARY KEY,
    name TEXT,
    addr FROZEN<address>
);
INSERT INTO employees (emp_id, name, addr) VALUES (uuid(), 'Eve', {'street': '123 Main', 'city': 'Anytown', 'zip': 12345});
SELECT addr FROM employees;
```

### Step 4.3: Secondary Indexes
For non-PK queries (use sparingly; prefer denormalization).
```
CREATE INDEX ON users (username);
SELECT * FROM users WHERE username = 'alice';
DROP INDEX ON users (username);
```

### Step 4.4: Tunable Consistency
Set read/write levels (e.g., ONE for speed, ALL for strong consistency).
```
CONSISTENCY QUORUM;
INSERT INTO users ...;  -- Applies to session
```

## Section 5: Queries and Aggregates

### Step 5.1: Advanced SELECT
```
-- Filter (must include partition key)
SELECT title, content FROM posts WHERE user_id = <user_id> AND post_id > minTimeuuid('2025-01-01 00:00:00');

-- Order by clustering
SELECT * FROM posts WHERE user_id = <user_id> ORDER BY post_id DESC LIMIT 5;

-- Aggregates
CREATE TABLE sales (product TEXT PRIMARY KEY, sales INT);
INSERT INTO sales (product, sales) VALUES ('laptop', 100);
INSERT INTO sales (product, sales) VALUES ('phone', 200);
SELECT COUNT(*), SUM(sales) FROM sales;
```

### Step 5.2: Batch Operations
```
BEGIN BATCH
  INSERT INTO users ...;
  UPDATE posts ...;
  DELETE FROM profiles ...;
APPLY BATCH;
```

## Section 6: Vector Search (Cassandra 5.0 Feature)

For AI/ML use cases (requires Storage-Attached Indexing - SAI).

### Step 6.1: Setup Vector Table
```
USE lab_keyspace;
CREATE TABLE vectors (
    id UUID PRIMARY KEY,
    embedding VECTOR<FLOAT, 3>,  -- 3D vector example
    description TEXT
);
CREATE INDEX vector_idx ON vectors (embedding) USING 'sai';
```

### Step 6.2: Insert and Query
```
INSERT INTO vectors (id, embedding, description) VALUES (uuid(), [0.1, 0.2, 0.3], 'Sample vector 1');
INSERT INTO vectors (id, embedding, description) VALUES (uuid(), [0.4, 0.5, 0.6], 'Sample vector 2');
-- ANN Search (Approximate Nearest Neighbors)
SELECT description, embedding 
FROM vectors 
ORDER BY embedding ANN OF [0.2, 0.3, 0.4] LIMIT 1;
-- With cosine similarity
SELECT description, similarity_cosine(embedding, [0.2, 0.3, 0.4]) AS score
FROM vectors 
ORDER BY embedding ANN OF [0.2, 0.3, 0.4] LIMIT 1;
```
Supported metrics: COSINE, DOT_PRODUCT, EUCLIDEAN.

## Exercises

Test your skills! Run these in your setup.

1. **Basic CRUD Challenge**: Create a `books` table (isbn UUID PK, title TEXT, author TEXT, pages INT). Insert 5 books, update 2 authors, delete 1, and query by pages > 300.

2. **Modeling Exercise**: Design two tables for a blog: one for posts by user (partition: user_id, cluster: date), another for posts by tag (partition: tag, cluster: post_id). Insert sample data and query "all posts by tag 'tech' ordered by date".

3. **Collections & UDTs**: Extend `users` with a UDT for `phone_numbers` (type, number) and a MAP for social links. Insert data and query users with 'mobile' phones.

4. **Query Optimization**: Add secondary index on `posts.content`. Query for keywords (e.g., CONTAINS 'Cassandra'). Discuss trade-offs (why avoid indexes?).

5. **Vector Fun**: Generate 5 random 5D vectors (use Python in a separate tool if needed), insert into `vectors`, and find top-3 similar to [0.5, 0.1, 0.8, 0.2, 0.9] using EUCLIDEAN.

6. **Batch & Consistency**: In a batch, insert 10 users with QUORUM consistency. Set to ONE, insert again, and compare `nodetool status` outputs.

**Verification**: Use `DESCRIBE TABLES;` to inspect schemas. For errors, check `docker logs cassandra-db`.

## Best Practices & Next Steps
- Model for queries: One table per query pattern.
- Monitor: `nodetool status` for cluster health.
- Scale: Add nodes via `docker run` on the same network.
- Resources: Official docs ([cassandra.apache.org](https://cassandra.apache.org/doc/5.0/)), DataStax Academy for certification.

This lab builds foundational skills. Experiment, break things, and rebuild! If stuck, query specifics in cqlsh's `HELP`.
