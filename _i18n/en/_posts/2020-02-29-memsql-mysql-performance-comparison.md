---
layout: post
title:  "MySQL and MemSQL performance comparison."
date: 2020-02-29 10:00:00 +0000
categories: memsql
canonical_url: https://www.enik.io/memsql/2020/02/29/memsql-mysql-performance-comparison.html
---
Recently I’ve reviewed [DBMS MemSQL](/memsql/2020/02/09/memsql-overview.html), that can store data by row and by column. MemSQL creators say that their solution works super fast. It was interesting to check it and comprehend how fast it is in comparison with MySQL (it was chosen because I use MySQL everyday) and what the difference is between rowstore and columnstore tables.

## Environment

I have used 6 CPU, 16 GB RAM with SSD hard drive virtual server for testing. Operational system - Ubuntu 18.04. MySQL version is 5.7.29, the storage engine is InnoDB. Default database settings have been used except cases when it was defined separately.

As a source of data for testing I have used information about taxi rides in New York in January of 2016. Links on the source files can be found in the repository [https://github.com/toddwschneider/nyc-taxi-data](https://github.com/toddwschneider/nyc-taxi-data), that includes statistics of all taxi rides in New York for few years. All tests have been run by shell or PHP scripts ([repository with these scripts](https://github.com/yenyasinn/memsql_test/)) for convenient usage and identical repeatability. All measurements have been made in milliseconds.

I was curious to know about different aspects of working with databases - data import, reading, updating, removing of data. So different tests have been written to cover various use cases.

Two different databases have been used in MemSQL to test rowstore and columnstore tables. In MySQL one specific database has been created for testing.

**Rowstore tables in MySQL and MemSQL:**

```sql
/* Rowstore */
CREATE TABLE yellow_tripdata_staging (
 id int(11) unsigned NOT NULL AUTO_INCREMENT,
 vendor_id tinyint,
 tpep_pickup_datetime datetime,
 tpep_dropoff_datetime datetime,
 passenger_count smallint,
 trip_distance float,
 pickup_longitude double(15,15),
 pickup_latitude double(15,15),
 rate_code_id tinyint,
 store_and_fwd_flag varchar(10),
 dropoff_longitude double(15,15),
 dropoff_latitude double(15,15),
 payment_type tinyint,
 fare_amount float,
 extra float,
 mta_tax float,
 tip_amount float,
 tolls_amount float,
 improvement_surcharge float,
 total_amount float,
 pickup_location_id varchar(255),
 dropoff_location_id varchar(255),
 congestion_surcharge varchar(255),
 junk1 varchar(255),
 junk2 varchar(255),
 PRIMARY KEY (`id`)
 /* INDEX (`rate_code_id`), */
 /* INDEX (`payment_type`) */
);

/* Rate code */
CREATE TABLE rate_code (
 rate_code_id tinyint,
 name varchar(255),
 PRIMARY KEY (`rate_code_id`)
);
INSERT INTO rate_code VALUES (1, 'Standard rate'), (2, 'JFK'), (3, 'Newark'), (4, 'Nassau or Westchester'), (5, 'Negotiated fare'), (6, 'Group ride');

/* Payment type */
CREATE TABLE payment_type (
 payment_type tinyint,
 name varchar(255),
 PRIMARY KEY (`payment_type`)
);
INSERT INTO payment_type VALUES (1, 'Credit card'), (2, 'Cash'), (3, 'No charge'), (4, 'Dispute'), (5, 'Unknown'), (6, 'Voided trip');
```

**Columnstore tables in MemSQL:**

```sql
/* MemSQL columnstore */

DROP TABLE IF EXISTS yellow_tripdata_staging;

CREATE TABLE yellow_tripdata_staging (
 id int(11) unsigned NOT NULL AUTO_INCREMENT,
 vendor_id tinyint,
 tpep_pickup_datetime datetime,
 tpep_dropoff_datetime datetime,
 passenger_count smallint,
 trip_distance float,
 pickup_longitude double(15,15),
 pickup_latitude double(15,15),
 rate_code_id tinyint,
 store_and_fwd_flag varchar(10),
 dropoff_longitude double(15,15),
 dropoff_latitude double(15,15),
 payment_type tinyint,
 fare_amount float,
 extra float,
 mta_tax float,
 tip_amount float,
 tolls_amount float,
 improvement_surcharge float,
 total_amount float,
 pickup_location_id varchar(255),
 dropoff_location_id varchar(255),
 congestion_surcharge varchar(255),
 junk1 varchar(255),
 junk2 varchar(255),
 KEY (`id`) USING CLUSTERED COLUMNSTORE
);

/* Rate code */
CREATE TABLE rate_code (
 rate_code_id tinyint,
 name varchar(255),
 KEY (`rate_code_id`) USING CLUSTERED COLUMNSTORE
);

INSERT INTO rate_code VALUES (1, 'Standard rate'), (2, 'JFK'), (3, 'Newark'), (4, 'Nassau or Westchester'), (5, 'Negotiated fare'), (6, 'Group ride');

/* Payment type */
CREATE TABLE payment_type (
 payment_type tinyint,
 name varchar(255),
 KEY (`payment_type`) USING CLUSTERED COLUMNSTORE
);

INSERT INTO payment_type VALUES (1, 'Credit card'), (2, 'Cash'), (3, 'No charge'), (4, 'Dispute'), (5, 'Unknown'), (6, 'Voided trip');
```

Main table with data - `yellow_tripdata_staging`. Tables `rate_code` and `payment_type` are used to store additional data.

## Loading data from the file.

MemSQL as MySQL supports importing data from files using command `LOAD DATA INFILE`. CSV file has been used for testing. File size is 1.5 GB and contains 10 906 859 lines.

<iframe width="100%" height="600px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=662724928&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

Results of the test show that the data is imported faster to the columnstore table.

After importing columnstore database has size 3.2GB, rowstore database - 4.8GB.

## Reading data.

Different SQL queries have been made up to check how databases work in different situations.

<table width="100%">
 <tr>
   <td colspan="2"><strong>Search by primary key.</strong></td>
 </tr>
 <tr>
   <td>S1:</td>
   <td>SELECT * FROM yellow_tripdata_staging WHERE id = 50</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Search by parameter.</strong></td>
 </tr>
 <tr>
   <td>S2:</td>
   <td>SELECT * FROM yellow_tripdata_staging WHERE payment_type = 2</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Search by range.</strong></td>
 </tr>
 <tr>
   <td>S3:</td>
   <td>SELECT * FROM yellow_tripdata_staging WHERE fare_amount >= 10 AND fare_amount <= 20</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Calculation of average value.</strong></td>
 </tr>
 <tr>
   <td>S4:</td>
   <td>SELECT avg(fare_amount) FROM yellow_tripdata_staging WHERE payment_type = 2</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Calculation of amount of items.</strong></td>
 </tr>
 <tr>
   <td>S5:</td>
   <td>SELECT count(*) FROM yellow_tripdata_staging WHERE payment_type = 2</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Search of the string.</strong></td>
 </tr>
 <tr>
   <td>S6:</td>
   <td>SELECT * FROM yellow_tripdata_staging WHERE store_and_fwd_flag LIKE 'Y%'</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Using a small limit.</strong></td>
 </tr>
 <tr>
   <td>S7:</td>
   <td>SELECT payment_type, pickup_longitude, pickup_latitude FROM yellow_tripdata_staging WHERE payment_type > 3 LIMIT 100</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Using a big limit.</strong></td>
 </tr>
 <tr>
   <td>S8:</td>
   <td>SELECT payment_type, pickup_longitude, pickup_latitude FROM yellow_tripdata_staging WHERE payment_type > 3 LIMIT 100000</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Using limit with offset.</strong></td>
 </tr>
 <tr>
   <td>S9:</td>
   <td>SELECT * FROM yellow_tripdata_staging LIMIT 100 OFFSET 100</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Search of dates in a range with sorting.</strong></td>
 </tr>
 <tr>
   <td>S10:</td>
   <td>SELECT tpep_pickup_datetime, tpep_dropoff_datetime FROM yellow_tripdata_staging WHERE tpep_pickup_datetime >= '2016-01-01 00:00:00' AND tpep_pickup_datetime <= '2016-01-01 01:00:00' ORDER BY tpep_pickup_datetime DESC</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Calculation of amount of items with grouping.</strong></td>
 </tr>
 <tr>
   <td>S11:</td>
   <td>SELECT COUNT(tip_amount), payment_type FROM yellow_tripdata_staging GROUP BY payment_type;</td>
 </tr>
 <tr>
   <td colspan="2"><strong>One inner join.</strong></td>
 </tr>
 <tr>
   <td>S12:</td>
   <td>SELECT pickup_longitude, pickup_latitude, r.name FROM yellow_tripdata_staging as t INNER JOIN rate_code as r ON t.rate_code_id = r.rate_code_id</td>
 </tr>
 <tr>
   <td colspan="2"><strong>Two inner joins.</strong></td>
 </tr>
 <tr>
   <td>S13:</td>
   <td>SELECT pickup_longitude, pickup_latitude, r.name, p.name FROM yellow_tripdata_staging as t INNER JOIN rate_code as r ON t.rate_code_id = r.rate_code_id INNER JOIN payment_type as p ON t.payment_type = p.payment_type</td>
 </tr>
</table>

For rowstore tables two different tests have been run. In the first one only primary key on the field `id` has been used. Such tests are marked as **“MySQL”** and **“MemSQL”**. Second test has been run with indexes on the fields `rate_code_id` and `payment_type`. These tests are marked as **“MySQL (index)”** and **“MemSQL (index)”** and exist if fields with index have been used in query. MySQL parameter `innodb_buffer_pool_size` is ~2.5 GB in tests with indexes. With the default parameter of  `innodb_buffer_pool_size` results were two times worse.


MemSQL columnstore tables can have one index only, so only one variant has been tested.

Tests have been run on the table `yellow_tripdata_staging` with ~11 millions, 1 million, 50 thousands  and 1 thousand rows to check the relation between performance of databases and size of tables.

Each test has been executed 3 times. Tests that show less time are considered as better. The best test from the first run is marked green. 

Results of the tests you can find below:

<iframe width="100%" height="1200px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=1689700170&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

First, what we see is that MySQL loses almost all tests with large amount of data (more than one million rows). In some cases adding indexes helps performance (tests S5, S7), but in other cases requests are run slower (test S11, S12, S13).

The test where MySQL wins is search by primary key (test S1). Also MySQL gets data well from the short limits (tests S7 and S9). But on the big limit performance falls dramatically (test S8).

MySQL competes with MemSQL on the tables with 50 thousand rows. Added indexes begin to show efficiency. I think that by fine tuning parameters MySQL can show results better on such a volume of data and show data comparable to MemSQL.

I was very surprised due to test results on the table with 1000 rows - MySQL works faster than MemSQL! Differences are a few milliseconds but if you need to execute thousands of requests then total time of execution can be seconds and difference in performance of the whole application will be visible.

MemSQL works better on the large amount of data. And the more data we have, the more the superiority of MemSQL over MySQL looks like. Columnstore works very well to acquire large amounts of data in specific range (tests S3, S8, S10). I have not had the opportunity to check but I assume that columnstore will show greater advantage over rowstore on the larger amount of data. Rowstore searches faster by strings (test S6) и and works better with  JOIN.

Using JOIN affects performance in all queries and databases (tests S12, S13). Therefore if we work with big data then it’s better to prepare data in advance and store processed data or  process data after receiving from the database to avoid joins in queries.

## Updating data

In the update tests I have reviewed two cases - updating of 10 000 records consistently (U1 - `UPDATE yellow_tripdata_staging SET tip_amount = 0, tolls_amount = 0 WHERE id = %d`) and updating of records using range (U2 - `UPDATE yellow_tripdata_staging SET tip_amount = 0, tolls_amount = 0 WHERE id >= 1 AND id <= 10000`). Tests have been run two times one right after another.

<iframe width="100%" height="520px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=1483495826&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

From the results we see that MemSQL columnstore updates single rows very slow. It was expected as we know from the theory that column oriented tables aren’t intended for frequent updates.

Updating the range is expectedly faster than updating single records because it is one transaction only.

Updating rows in the first run happens faster in MemSQL rowstore. As we already saw in the reading tests MySQL works very well with primary key. So updating rows in the second run works faster in MySQL.

## Adding data

Adding data was tested twice. In the first test 10 000 lines have been added consistently. In the second test 10 queries by 1000 lines in each have been run.

<iframe width="100%" height="520px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=2086513471&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

As anticipated, it is much more effective to add data by big chunks in any database. When we add data by lines then MemSQL does it faster.

## Removing data

In this test three cases have been considered:

* **Test D1** - deletion of 10 000 random rows;
* **Test D2** - deletion of 10 000 rows using range by primary key.
* **Test D3** - deletion of 10 000 000 rows.

<iframe width="100%" height="650px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=1003358391&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

As we already saw, it is faster to update and remove lines by big groups.

MemSQL columnstore is slowest in removing of 10 000 lines (tests D1, D2) but it is fastest in removing of 10 000 000 rows.

In the test D1 (removing of 10 000 rows) the best performance showed MemSQL rowstore. But I think that if in MySQL primary keys were indexed then it would win.

## Conclusion
 
After tests are done we can conclude that difference in performance MySQL and MemSQL depends on the size of tables highly. MySQL is better suited for tables up to a few dozen thousand rows especially when indexes are used. Given that MemSQL is quite demanding on the minimum server resources, I think that using it on such data volumes is not practical.

MemSQL shows results much better than MySQL when number of rows above million.  It is the scope of MemSQL - big data. Looks like it is a reason why MemSQL is free in usage on the clusters with limited resources - you can't store more than one hundred gigabytes in the rowstore table on the free plan (but it can be enough for many applications). I have not had a chance to check but I suppose that on the very large amount of information (hundreds of gigabytes, terabytes) columnstore will be more effective than rowstore in the reading and writing information especially if you don’t need to update data frequently. 
 
**I would characterise scope of application of these databases as:**
 
* Tables up to a few dozen thousands rows - MySQL.
* Tables with more than a million rows with frequent updates - MemSQL rowstore.
* Tables with more than a million rows with rare updates - MemSQL columnstore.

## What is about Drupal?

Drupal is well constructed and uses effectively the advantages of traditional databases like MySQL and PostgreSQL. Let’s have a look on the typical requests in Drupal on the example of two sites with 10 and 500 000 nodes:

<iframe width="100%" height="520px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=108804055&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

As you see Drupal uses search by primary key and MySQL works fine in this case. But there is also writing cache data where MemSQL is more performant. In reality we often use key-value storages such as Redis or Memcache to decrease load on the database and in this case writing to the DB is rare.

I’ve decided to measure output of 10 nodes with enabled and disabled Memcache on the sites with 50, 50 000 and 500 000 nodes to understand what is more effective for Drupal - MySQL or MemSQL. You can find results below: 

<iframe width="100%" height="520px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=491586049&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

In the first run with “cold” cache Drupal + MemSQL is a little bit faster, but if the page is cached then Drupal + MySQL + Memcache shows better performance. But the difference isn’t significant.

If you use Drupal to store content then, highly likely, you won’t see a big difference between MemSQL and MySQL. In this case better to [use reverse proxy for caching](/drupal/performance/2019/10/06/reverse-proxy-caching.html), especially considering that MemSQL requires a high performance server.

**MemSQL can be used effectively if Drupal is used as:**

* Real-time analytical platform.
* Dashboard.
* Search system by parameters (for example, search by hotels or flights).
* System with frequent data updates.
* Storage of huge amount of data (hundreds of gigabytes).
