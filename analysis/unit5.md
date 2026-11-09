# Unit 5 Write-ups

## Task 5.1: Connect Producers to Their Data

### 1. What feature or report could use the three-table join? What would it display?

A trip history report for Driver Operations and Rider Support. Instead of making someone look up a trip ID, then separately look up the rider and driver, the report puts everything on one line: the trip ID, rider and driver IDs and names, when the trip was requested and finished, its status, and any cancellation reason. The join returns all **200 trips**, including the **34 cancelled trips** that have no completion timestamp. For those, the report says **"Not completed"** rather than showing an empty timestamp.

That would be useful when someone asks what actually happened on a particular rider no-show. We could pull up the trips associated with drivers **2 and 3**, whom we flagged in Unit 4, and see the individual records instead of only their percentages. The report doesn't tell us whether the driver arrived or how long they waited; we'd need other records to answer that.

### 2. Why is the junction table important? What would be harder without it?

A driver can earn several badges, and the same badge can be earned by several drivers. The `driver_badge_awards` table keeps track of those driver-and-badge pairings, including when each award was made. It lets me connect `drivers` to `driver_badges` without cramming a list of badges into a single column or repeating all of a driver's information for every award. Without it, finding everyone who earned a particular badge—or comparing badges across drivers—would be much messier.

The query shows **eight awards across drivers 2, 3, and 4**. Drivers **2 and 3 both have Night Owl**, drivers **2 and 4 share Safe Driving**, and drivers **3 and 4 share Clean Car**. No single badge is shared by all three. Night Owl also belongs to drivers **5, 10, and 11**, so I wouldn't treat it as an explanation for no-shows just because both drivers we're investigating have it.

### What the self-joins added

I tried two different comparisons rather than going over driver ratings again, since Unit 4 already showed that high ratings didn't line up neatly with low no-show rates.

The first compares each flagged driver with others based in the **same home city**. Driver **2** is the only driver based in Danang, so there's no local peer in the table. Driver **3** has **2 no-shows in 13 trips (15.38%)**, compared with Haiphong-based drivers **6** and **11**, who have **1 in 21 (4.76%)** and **1 in 16 (6.25%)**. Driver **4** has **1 in 6 (16.67%)**; its Saigon peers have larger trip histories, except driver **14**, who has no trips at all. Home city is only where a driver is based, though. We learned in Unit 4 that drivers don't necessarily pick riders up there, so this is a comparison of home locations, not proof of similar working conditions.

The second comparison looks at **roughly similar trip counts**, using a range within **25%** of each flagged driver's volume and leaving drivers 2, 3, and 4 out of one another's comparison groups. Driver **2's 18.75%** rate compares with **3.28%** across seven peers; driver **3's 15.38%** compares with **5.77%** across four peers. Driver **4** has no peers in that range. The 25% range is an exploratory choice, the peer groups overlap, and we're talking about only a few no-shows. It supports a closer look at drivers 2 and 3, not a conclusion that either caused the rider no-shows.

## Task 5.2: Find Records That Joins May Exclude

### 1. Which producers were excluded by the INNER JOIN? Report their identifiers.

**Drivers 14 and 15.** The LEFT JOIN report has **15 drivers**, including these two with zero trips. The INNER JOIN report has **13**, because it only keeps drivers who have at least one matching trip. The count difference is **two drivers**, and both the `NOT EXISTS` and `EXCEPT` checks identify the same IDs.

### 2. What does it mean when a producer has no events? What might explain it?

In this dataset, it means **no trip is recorded for that driver during 2023**. It doesn't mean the driver has never driven, and it doesn't tell us why. Drivers **14** (Saigon, onboarded April 11, 2022) and **15** (Hue, onboarded November 18, 2022) are both marked **active**, even though neither has a trip in the table. Maybe they never got trip offers, weren't fully set up, stopped accepting rides, or have activity that isn't in this dataset. We can't choose among those explanations from these tables alone. They also have stored ratings, but the data doesn't tell us when those ratings were calculated or where they came from.

### 3. How could an INNER JOIN-only report give leadership an incomplete picture?

It would make drivers **14 and 15 disappear altogether**, not show them as drivers with zero trips. Leadership could easily read that as "we have 13 drivers" when we actually have **15 registered drivers**. It can also skew a workload comparison: **200 trips divided by 13 drivers with trips is about 15.38 per driver**, while **200 divided by all 15 registered drivers is about 13.33**. Those are two valid averages, but they answer different questions. If the report silently drops the zero-trip drivers, nobody gets to choose which question they meant to ask.

### 4. Why would leadership want to identify producers who have never been active?

Because drivers who are registered but have no recorded trips may point to a very different problem than drivers with unusual no-show rates. There could be a problem with onboarding, getting trip offers, account status, where drivers are located, or simply how activity is recorded. Knowing who has zero trips helps Driver Operations check whether available drivers are actually able to work. But the **active** flag is only what the table currently says; it isn't proof that a driver was available throughout 2023.

### 5. What action should leadership take?

Start with a **status and onboarding check** for drivers **14 and 15**. Driver Operations should verify whether their accounts are still meant to be active, whether they were eligible to receive trip offers, and whether they actually received any. Trust and Data should check whether any trip history was missed or whether the activity flag and ratings are out of date. If the issue is an onboarding or dispatch problem, help resolve it; if the driver has simply stopped participating, update the records. Either way, **don't group them with drivers 2 and 3**. No recorded trips and an elevated recorded no-show rate are different situations.

### What the other joins and anti-joins confirmed

Reversing the table order with a RIGHT JOIN gave the **same 15 driver rows and trip counts** as the LEFT JOIN. I compared the actual report rows—not just the counts—and found **zero differences in either direction**. The FULL OUTER JOIN produced **202 rows**: **200 matched driver-trip rows**, **two drivers without trips**, and **no trips with a missing driver record**. It can show missing records on either side at once; the zero on the trip-only side also makes sense because the trip table has a foreign key requiring a valid driver.

`NOT EXISTS` checks each driver for the absence of a matching trip, while `EXCEPT` subtracts the driver IDs found in `trips` from the complete list in `drivers`. **Both return drivers 14 and 15**, and the two-way set comparison shows **no IDs appearing in only one result**.

## Task 5.3: Understand Join Performance and Execution Plans

### 1. When could a Cartesian product be useful on this platform?

The driver-and-badge example is a good use for one. We have **15 drivers** and **five badge types**, so a CROSS JOIN makes **75 possible pairings**. Only **25** are recorded as awards, leaving **50 driver-badge combinations without an award**. That could help build a badge-progress report or find missing combinations to investigate. An unawarded badge does **not** mean the driver qualifies for it.

It would be a mistake if I accidentally used a CROSS JOIN when I meant to connect trips to their actual drivers. **200 trips times 15 drivers would create 3,000 rows**, even though there are only 200 real trip-to-driver assignments. That's the kind of error that can look fine at first glance and completely throw off a report.

### 2. Which join algorithms did PostgreSQL choose for the three-table query?

PostgreSQL used a **Hash Join** to connect trips to riders and then a **Nested Loop** to connect those results to drivers. The Nested Loop uses **Memoize** to remember driver lookups and an **Index Scan on `drivers_pkey`** to find drivers it hasn't already cached. A **Sort** puts the results in requested-time and trip-ID order. There's no Merge Join in the plan.

Running `EXPLAIN ANALYZE` confirmed both joins produced **200 rows**, exactly as the planner expected. The interesting part is Memoize: it had **187 cache hits and 13 misses** over 200 lookups, so PostgreSQL only searched the driver index **13 times**.

### 3. What in the execution plan helps explain those choices?

PostgreSQL reads the whole `trips` table with a **Seq Scan** (200 actual rows) and scans `riders` to build a small hash table. It estimated **100 riders**, but the actual scan found **30**. The hash was only **10kB**, so hashing that small table and matching it to all 200 trips makes sense for this report.

For drivers, the plan uses the `drivers_pkey` index inside a Nested Loop. We have **15 registered drivers**, but only **13** occur in the trip history. The **13 Memoize misses and 13 index searches** line up with those 13 distinct drivers; the other 187 lookups were cache hits. The cache itself used **2kB** and had no evictions. We don't have separate indexes on `trips.rider_id`, `trips.driver_id`, or `trips.requested_at` in the supplied dataset.

At the top, the Sort uses **quicksort and 46kB of memory** for the 200-row result. That means the sort stayed in memory in this run. PostgreSQL reported **0.351 ms planning time** and **6.872 ms execution time**. That's useful as one measurement, but not a reliable speed benchmark by itself.

#### Full PostgreSQL EXPLAIN plan

```text
Sort  (cost=36.48..36.98 rows=200 width=613)
  Sort Key: t.requested_at, t.trip_id
  ->  Nested Loop  (cost=12.40..28.84 rows=200 width=613)
        ->  Hash Join  (cost=12.25..17.80 rows=200 width=314)
              Hash Cond: (t.rider_id = r.rider_id)
              ->  Seq Scan on trips t  (cost=0.00..5.00 rows=200 width=56)
              ->  Hash  (cost=11.00..11.00 rows=100 width=262)
                    ->  Seq Scan on riders r  (cost=0.00..11.00 rows=100 width=262)
        ->  Memoize  (cost=0.15..0.41 rows=1 width=262)
              Cache Key: t.driver_id
              Cache Mode: logical
              ->  Index Scan using drivers_pkey on drivers d  (cost=0.14..0.40 rows=1 width=262)
                    Index Cond: (driver_id = t.driver_id)
```

#### Full PostgreSQL EXPLAIN ANALYZE plan

```text
Sort  (cost=36.48..36.98 rows=200 width=613) (actual time=6.816..6.824 rows=200.00 loops=1)
  Sort Key: t.requested_at, t.trip_id
  Sort Method: quicksort  Memory: 46kB
  Buffers: shared hit=33
  ->  Nested Loop  (cost=12.40..28.84 rows=200 width=613) (actual time=6.166..6.651 rows=200.00 loops=1)
        Buffers: shared hit=30
        ->  Hash Join  (cost=12.25..17.80 rows=200 width=314) (actual time=0.080..0.236 rows=200.00 loops=1)
              Hash Cond: (t.rider_id = r.rider_id)
              Buffers: shared hit=4
              ->  Seq Scan on trips t  (cost=0.00..5.00 rows=200 width=56) (actual time=0.036..0.087 rows=200.00 loops=1)
                    Buffers: shared hit=3
              ->  Hash  (cost=11.00..11.00 rows=100 width=262) (actual time=0.033..0.034 rows=30.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 10kB
                    Buffers: shared hit=1
                    ->  Seq Scan on riders r  (cost=0.00..11.00 rows=100 width=262) (actual time=0.017..0.020 rows=30.00 loops=1)
                          Buffers: shared hit=1
        ->  Memoize  (cost=0.15..0.41 rows=1 width=262) (actual time=0.001..0.001 rows=1.00 loops=200)
              Cache Key: t.driver_id
              Cache Mode: logical
              Hits: 187  Misses: 13  Evictions: 0  Overflows: 0  Memory Usage: 2kB
              Buffers: shared hit=26
              ->  Index Scan using drivers_pkey on drivers d  (cost=0.14..0.40 rows=1 width=262) (actual time=0.003..0.003 rows=1.00 loops=13)
                    Index Cond: (driver_id = t.driver_id)
                    Index Searches: 13
                    Buffers: shared hit=26
Planning Time: 0.351 ms
Execution Time: 6.872 ms
```

### 4. Why is it useful to understand the join algorithms?

Just because a query gives the right answer now doesn't mean it'll stay efficient as the platform grows. The plan tells us **how PostgreSQL is getting the answer**. Here, `EXPLAIN ANALYZE` also shows the difference between estimates and actual behavior: it expected 100 riders but scanned 30, and Memoize saved 187 repeated lookups. Those details help us decide where an index, different filter, or rewrite might actually make a difference instead of just guessing.

### 5. What changes might make a different algorithm more appropriate?

With many more trips, the sequential scan and final Sort could become more expensive. The Sort currently uses only **46kB**, but sorting millions of rows might need much more memory or spill to disk. More *distinct* drivers could also cut into Memoize's benefit: with 13 different driver IDs, it only needed 13 index searches, but with thousands of drivers it could have far more misses. If the rider table grew much larger, the Hash Join might need a bigger hash table, or PostgreSQL might prefer another approach.

Adding indexes to trip foreign keys could help a report filtered to particular drivers or riders, though it wouldn't automatically improve this report, which includes every trip. A Merge Join could become attractive if both inputs were already sorted in a useful way. The point is to match the plan to the data size, how many rows match, and which indexes exist—not to assume one join type is always best.

### Reflection (150–250 words)

The first EXPLAIN showed a Hash Join between trips and riders, followed by a Nested Loop to connect drivers. When I ran EXPLAIN ANALYZE, both joins actually returned 200 rows, so those estimates were right. But PostgreSQL estimated 100 riders when it really scanned 30, which reminded me that the plan is working from estimates, not perfect knowledge of the data.

What surprised me most was Memoize. The query needed 200 driver lookups, but 187 came from its cache and only 13 required index searches. That works well here because lots of trips refer to the same small group of drivers. If the platform grew to thousands of drivers and trips were spread more evenly across them, there might be fewer cache hits, and PostgreSQL could decide a different join would be cheaper.

The Sort was also tiny: 46kB for 200 results. With millions of trips, that could become a much bigger job, possibly needing disk space. New indexes on trip foreign keys might help reports filtered to a few riders or drivers, but probably wouldn't be a magic fix for a report that reads everything. Bigger tables, different matching patterns, and better indexes could all change which join algorithm PostgreSQL picks. That's why I'd check the plan again as the data changes instead of assuming today's quick run will stay quick.
