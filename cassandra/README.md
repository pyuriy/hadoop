# Apache Cassandra Cheatsheet

Apache Cassandra is a distributed NoSQL database designed for high availability, scalability, and fault tolerance, following the AP (Availability and Partition tolerance) aspects of the CAP theorem. This cheatsheet covers essential concepts, CQL (Cassandra Query Language) commands, data types, and operations. It's compiled from key resources for quick reference.

## Data Types

Cassandra supports native types, collections, user-defined types (UDTs), and tuples.

### Native Types

| Data Type | Description | Constants Supported | Example |
|-----------|-------------|---------------------|---------|
| ascii | ASCII character string | string | `'hello'` |
| text/varchar | UTF-8 encoded string | string | `'world'` |
| inet | IPv4 or IPv6 address | string | `'192.168.0.1'` |
| boolean | true or false | boolean | `true` |
| blob | Arbitrary bytes (e.g., images) | blob | `0xDEADBEEF` |
| duration | Duration (months, days, nanoseconds) | duration | `P1M2D` |
| tinyint | 8-bit signed int | integer | `127` |
| smallint | 16-bit signed int | integer | `32767` |
| int | 32-bit signed int | integer | `2147483647` |
| bigint | 64-bit signed long | integer | `9223372036854775807` |
| varint | Arbitrary-precision integer | integer | `12345678901234567890` |
| counter | 64-bit signed counter | integer | N/A (increment only) |
| decimal | Variable-precision decimal | integer, float | `3.14` |
| double | 64-bit floating-point | integer, float | `3.14159` |
| float | 32-bit floating-point | integer, float | `3.14` |
| date | Date (without time) | integer, string | `'2025-11-18'` |
| time | Time (without date) | integer, string | `'12:34:56.789'` |
| timestamp | Date and time | integer, string | `'2025-11-18 12:34:56'` |
| uuid | UUID (any version) | uuid | `uuid()` |
| timeuuid | Version 1 UUID | uuid | `now()` |

### Collection Types
- **List**: Ordered, allows duplicates. Syntax: `list<type>`, e.g., `['item1', 'item2']`.
- **Set**: Unordered, unique values. Syntax: `set<type>`, e.g., `{'item1', 'item2'}`.
- **Map**: Key-value pairs. Syntax: `map<key_type, value_type>`, e.g., `{'key1': 'value1'}`.

### User-Defined Types (UDTs)
```
CREATE TYPE address (
  street text,
  city text,
  zip int
);
```

### Tuples
Inline fixed-size collections: `tuple<type1, type2>`, e.g., `(1, 'foo', 3.14)`.

## Keyspace Management
A keyspace is like a schema or database in RDBMS, defining replication.

| Command | Syntax | Example |
|---------|--------|---------|
| CREATE | `CREATE KEYSPACE ks WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};` | `CREATE KEYSPACE school WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};` |
| ALTER | `ALTER KEYSPACE ks WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 3};` | `ALTER KEYSPACE school WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 3};` |
| USE | `USE ks;` | `USE school;` |
| DROP | `DROP KEYSPACE ks;` | `DROP KEYSPACE school;` |
| DESCRIBE | `DESCRIBE KEYSPACES;` or `DESCRIBE KEYSPACE ks;` | `DESCRIBE KEYSPACE school;` |

## Table Management
Tables require a PRIMARY KEY (partition key + optional clustering columns).

| Command | Syntax | Example |
|---------|--------|---------|
| CREATE | `CREATE TABLE ks.table (col1 type PRIMARY KEY, col2 type);` | `CREATE TABLE school.students (id UUID PRIMARY KEY, name TEXT, age INT);` |
| ALTER (ADD) | `ALTER TABLE ks.table ADD col type;` | `ALTER TABLE school.students ADD email TEXT;` |
| ALTER (TYPE) | `ALTER TABLE ks.table ALTER col TYPE new_type;` | `ALTER TABLE school.students ALTER age TYPE SMALLINT;` |
| ALTER (PROPERTIES) | `ALTER TABLE ks.table WITH caching = {'keys': 'NONE'};` | `ALTER TABLE school.students WITH caching = {'keys': 'NONE'};` |
| DROP | `DROP TABLE ks.table;` | `DROP TABLE school.students;` |
| TRUNCATE | `TRUNCATE ks.table;` | `TRUNCATE school.students;` |
| DESCRIBE | `DESCRIBE TABLE ks.table;` | `DESCRIBE TABLE school.students;` |

## Data Manipulation

| Command | Syntax | Example |
|---------|--------|---------|
| INSERT | `INSERT INTO ks.table (col1, col2) VALUES (val1, val2);` | `INSERT INTO school.students (id, name, age) VALUES (uuid(), 'John Doe', 20);` |
| UPDATE | `UPDATE ks.table SET col = val WHERE pk = val;` | `UPDATE school.students SET age = 21 WHERE id = uuid1;` |
| SELECT | `SELECT * FROM ks.table WHERE pk = val;` | `SELECT name FROM school.students WHERE age > 18;` |
| DELETE | `DELETE FROM ks.table WHERE pk = val;` | `DELETE FROM school.students WHERE id = uuid1;` |

### Batch Operations
```
BEGIN BATCH
  INSERT INTO ks.table ...;
  UPDATE ks.table ...;
APPLY BATCH;
```
Example:
```
BEGIN BATCH
  INSERT INTO school.students (id, name, age) VALUES (uuid(), 'Jane', 22);
  INSERT INTO school.students (id, name, age) VALUES (uuid(), 'Tom', 23);
APPLY BATCH;
```

## Indexes
Primary keys are auto-indexed; secondary indexes for non-PK columns.

| Command | Syntax | Example |
|---------|--------|---------|
| CREATE | `CREATE INDEX idx ON ks.table (col);` | `CREATE INDEX name_idx ON school.students (name);` |
| DROP | `DROP INDEX ks.idx;` | `DROP INDEX school.name_idx;` |

## Advanced Queries
- **WHERE**: Must include full partition key; clustering keys optional. Operators: `=`, `>`, `<`, `>=`, `<=`, `IN`, `CONTAINS` (collections).
- **ORDER BY**: On clustering columns only, e.g., `SELECT * FROM table WHERE pk=val ORDER BY ck ASC;`
- **LIMIT**: `SELECT * FROM table LIMIT 10;`
- **GROUP BY**: On partition/clustering keys: `SELECT col FROM table GROUP BY pk, ck;`

## Functions
- **TTL(col)**: Time-to-live in seconds. `SELECT TTL(age) FROM school.students;`
- **WRITETIME(col)**: Timestamp of last write. `SELECT WRITETIME(age) FROM school.students;`
- **TOKEN(pk)**: Partition token. `SELECT TOKEN(id) FROM school.students;`
- Aggregates: `MIN`, `MAX`, `SUM`, `AVG`, `COUNT`. e.g., `SELECT COUNT(*) FROM table;`
- UUID/TimeUUID: `uuid()`, `now()`.

## User/Role Management

| Command | Syntax | Example |
|---------|--------|---------|
| CREATE USER | `CREATE USER user WITH PASSWORD 'pass';` | `CREATE USER admin WITH PASSWORD 'secret';` |
| ALTER USER | `ALTER USER user WITH PASSWORD 'newpass';` | `ALTER USER admin WITH PASSWORD 'newsecret';` |
| DROP USER | `DROP USER user;` | `DROP USER admin;` |
| GRANT | `GRANT ALL ON KEYSPACE ks TO user;` | `GRANT SELECT ON KEYSPACE school TO admin;` |
| REVOKE | `REVOKE ALL ON KEYSPACE ks FROM user;` | `REVOKE SELECT ON KEYSPACE school FROM admin;` |

## Operators
- Arithmetic: `+`, `-`, `*`, `/`, `%`, unary `-`.
- Conditional (in WHERE): `=`, `!=`, `>`, `<`, `>=`, `<=`, `IN`, `CONTAINS`, `CONTAINS KEY`.

## Quick Tips
- Always specify PRIMARY KEY in CREATE TABLE.
- Use `cqlsh` for CLI: `cqlsh host 9042 -u user -p pass`.
- Replication: SimpleStrategy for single DC; NetworkTopologyStrategy for multi-DC.
- For production, monitor with Nodetool (e.g., `nodetool status`).

For more details, refer to official docs at [cassandra.apache.org](https://cassandra.apache.org).
