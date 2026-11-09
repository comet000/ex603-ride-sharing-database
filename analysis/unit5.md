# Unit 5 Write-ups

## Task 5.1: Connect producers to their data

### What the three-table join is for

The `trips` table already tells us which rider and driver IDs belong to each trip, when it was requested, and what happened to it. What it doesn't have are the people's names. Joining `riders` and `drivers` adds those names, so Rider Support or Driver Operations can look up a trip without having to match two IDs to separate lists.

The result is a trip history, not a new performance measure. It shows all 200 trips involving 30 riders and 13 drivers, including the 34 cancelled trips whose completion time is shown as "Not completed." Unit 3 had already counted the 12 rider no-shows and used three different query forms to identify the drivers associated with them. This join brings both people's names into a single trip record. Staff could filter to those 12 trips for an investigation, but as written, the report includes every trip.

### What the badge records tell us

A driver can hold several badges, and a badge can belong to several drivers. That's why `driver_badge_awards` matters: it connects `drivers` to `driver_badges` and records when each award was made. Without it, we'd have to repeat driver records or store a list of badges in one field, which would make checking who earned what much harder.

Drivers 2, 3, and 4 have eight awards between them, but no badge is shared by all three. Drivers 2 and 3 both hold **Night Owl**; drivers 2 and 4 share **Safe Driving**, while drivers 3 and 4 share **Clean Car**. I used Night Owl for the second lookup because drivers 2 and 3 both hold it. Five drivers hold it (2, 3, 5, 10, and 11). Their no-show records are different, though, so the shared badge doesn't explain the no-shows. In fact, none of the five no-show trips associated with drivers 2 and 3 was requested after 10 p.m. Unit 4 had also checked driver ratings: drivers 2 and 13 both had a rating of 4.94, yet one had three no-shows and the other had none. The badge is another characteristic to check, not an explanation by itself.

### What the driver comparisons add

The first self-join compares drivers based in the same **home city**. Driver 2 has no other Danang-based driver to compare with. Driver 3 has two Haiphong peers: driver 6 had 1 no-show in 21 trips (4.76%), and driver 11 had 1 in 16 (6.25%), compared with driver 3's 2 in 13 (15.38%). Driver 4 has four Saigon peers (5, 7, 8, and 14). Driver 14 has no trips, so their rate is **NULL**, not 0%. Unit 4 made the difference between home city and pickup city clear: only 44 of the 200 trips began in the driver's home city. These are comparisons between drivers based in the same city, not necessarily drivers working in the same pickup areas.

The second comparison asks a different question: do drivers with a similar number of trips have similar no-show rates? I used a range of 25% above or below each driver's trip count and left drivers 2, 3, and 4 out of one another's comparison groups. Q3a is the direct self-join of `drivers`; Q3b compares the driver activity summaries.

| Driver | Own no-show rate | Drivers with similar trip counts |
|---|---:|---|
| 2 | **18.75%** (3 of 16) | **3.28%** (4 of 122 trips across 7 peers) |
| 3 | **15.38%** (2 of 13) | **5.77%** (3 of 52 trips across 4 peers) |
| 4 | **16.67%** (1 of 6) | No qualifying peers; rate is **NULL** |

Drivers 2 and 3 still stand out when trip volume is taken into account. The peer groups overlap: drivers 9 and 11 appear in both comparisons. Driver 4's one no-show on six trips is still too little to judge, which is why Unit 4 put that driver on the watch list rather than the investigation list. These comparisons tell us where no-shows were recorded. They don't tell us why the riders didn't show up.

## Task 5.2: Find records that joins may exclude

### The two drivers the earlier breakdown missed

Unit 4's per-driver queries had already noted that drivers **14 and 15** were absent because they had no trips. The join comparison now shows exactly why: the `LEFT JOIN` retains all **15 registered drivers**, but the equivalent `INNER JOIN` keeps only the **13** with matching trip records.

Both missing drivers are marked active. Driver 14 is based in Saigon, was onboarded on April 11, 2022, and has a stored rating of 3.63. Driver 15 is based in Hue, was onboarded on November 18, 2022, and has a rating of 4.00. Neither has a trip in the 2023 data. That is **zero recorded activity**, not proof that either driver has never worked. They might have driven outside the period we have, had a dispatch or setup problem, or have history missing from this dataset. The ratings make it especially worth checking their account records, but they don't settle the question.

### Why the missing rows matter

An inner-join-only report makes the platform look smaller than it is. It would show 13 drivers rather than 15 and could make average driver activity look higher. With all registered drivers included, there are **200 / 15 = 13.33 trips per driver**. Looking only at drivers with at least one trip gives **200 / 13 = 15.38**. Both averages are correct, but they answer different questions. Leadership needs to know which group a report covers.

Unit 3 showed a different way a report can leave records out: using `cancellation_reason != 'Rider no show'` silently excluded 166 trips whose cancellation reason was NULL. Here the missing rows come from an unmatched join rather than a NULL comparison, but the lesson is the same: a query can run without errors and still give an incomplete picture.

This is worth following up because someone marked active but showing no trips might be unable to receive work, might not actually be available, or might simply be absent from the trip history we were given. Driver Operations should confirm the accounts and dispatch eligibility; Trust and Data should check whether earlier trips are missing and where the ratings came from. Until then, the report should show drivers 14 and 15 with zero trips rather than drop them.

### Checking the join results

Reversing the table order and using `RIGHT JOIN` gives the same driver IDs, names, and trip counts as the `LEFT JOIN`. I checked the actual rows in both directions with `EXCEPT`, not just their counts, and found no differences.

The `FULL OUTER JOIN` gives **202 rows**: 200 matched driver-trip rows, two driver records without trips, and no trips without a driver record. The absence of trip-only rows is consistent with the foreign-key constraint requiring each trip to reference an existing driver. The full join can show missing records from either side in the same result. The two ways of finding drivers without trips, `NOT EXISTS` and `EXCEPT`, also agree on drivers 14 and 15. The first tests whether a matching trip exists; the second subtracts driver IDs found in trips from the full driver list. `NOT EXISTS` also avoids the NULL problem with `NOT IN` that I tested in Unit 3.

I used a `FULL OUTER JOIN` in Unit 3 to check whether three ways of finding no-show drivers returned the same records. Here it serves a different purpose: showing matched trips and missing driver or trip records together.

I also checked account flags against recorded activity. Drivers 3 and 9 are marked inactive even though they have trips from 2023, while drivers 14 and 15 are marked active with none. That isn't necessarily inconsistent: we don't have a date for when each active flag was set, and a driver could have stopped after their last trip. It gives us more account records to confirm, not four proven data errors.

## Task 5.3: Understand join performance and execution plans

### When a cross join is useful

Crossing all 15 drivers with the five badge types makes **75 driver-badge pairs**. That gives us a complete list of possible pairings to check against the awards table: **25 have an award record and 50 do not**. A missing award doesn't mean the driver qualified for it, just that no award is recorded.

I also used `CROSS JOIN` in Unit 4, but for a different reason. There, it put a single baseline result beside each busier driver's figures. Since the baseline had only one row, the cross join didn't increase the number of driver rows. Here I deliberately want every driver paired with all five badges.

A cross join is a problem when those combinations aren't what we meant to ask for. If a trip report accidentally paired every trip with every driver, we'd get **200 × 15 = 3,000 rows** instead of the 200 actual trip-driver relationships. The extra 2,800 pairs would be made up by the query, not by the data.

### What PostgreSQL did with the three-table join

The plan joins `trips` to `riders` with a **Hash Join**, then connects the result to `drivers` with a **Nested Loop** and an index lookup on `drivers_pkey`. `Memoize` remembers the driver records it has already fetched. There is no Merge Join. A final Sort puts the trips in requested-time order.

The table sizes help explain that choice. PostgreSQL read 200 trips and built a small hash from 30 riders, using just **10 kB**. It estimated 100 riders rather than 30, which could mean its statistics were out of date. That hasn't been checked; running `ANALYZE` would refresh the statistics. The absence of a separate index on `trips.rider_id` isn't what forced the Hash Join, since `riders_pkey` could also support indexed lookups into riders. PostgreSQL chose to hash this small table for this run.

The driver side shows why the nested loop worked well here. There were **200 driver lookups**, but **187 were Memoize cache hits**, leaving only **13 actual index searches**. The last Sort handled 200 rows in 46 kB of memory. In the recorded run, planning took **0.273 ms** and execution took **0.465 ms**. That's a measurement of one run on this small dataset, not a performance target for the platform.

### What the plan helps us anticipate

Knowing the algorithm tells us where extra work will land if the platform grows. With many more trips, the full scan of `trips` and the final Sort would have much more to do, and a large sort could run out of memory and spill to disk. If trips were spread across many more distinct drivers, Memoize would help less and a Hash Join to `drivers` might be cheaper. If larger inputs were already ordered on the join keys, PostgreSQL might prefer a Merge Join instead.

Indexes on trip foreign keys could help with a report looking at one driver or a handful of riders, but they wouldn't automatically speed up this report, which reads every trip. That's why the plan is worth checking again when the number of rows, the available indexes, or the shape of the query changes.

### Recorded PostgreSQL plans

These are the full `EXPLAIN` and `EXPLAIN ANALYZE` outputs for the three-table join. The executable queries are in `q5_3.sql`, and the results are also documented in the screenshots.

**EXPLAIN**

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

**EXPLAIN ANALYZE**

```text
Sort  (cost=36.48..36.98 rows=200 width=613) (actual time=0.377..0.384 rows=200.00 loops=1)
  Sort Key: t.requested_at, t.trip_id
  Sort Method: quicksort  Memory: 46kB
  Buffers: shared hit=30
  ->  Nested Loop  (cost=12.40..28.84 rows=200 width=613) (actual time=0.112..0.310 rows=200.00 loops=1)
        Buffers: shared hit=30
        ->  Hash Join  (cost=12.25..17.80 rows=200 width=314) (actual time=0.068..0.134 rows=200.00 loops=1)
              Hash Cond: (t.rider_id = r.rider_id)
              Buffers: shared hit=4
              ->  Seq Scan on trips t  (cost=0.00..5.00 rows=200 width=56) (actual time=0.029..0.052 rows=200.00 loops=1)
                    Buffers: shared hit=3
              ->  Hash  (cost=11.00..11.00 rows=100 width=262) (actual time=0.027..0.028 rows=30.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 10kB
                    Buffers: shared hit=1
                    ->  Seq Scan on riders r  (cost=0.00..11.00 rows=100 width=262) (actual time=0.012..0.015 rows=30.00 loops=1)
                          Buffers: shared hit=1
        ->  Memoize  (cost=0.15..0.41 rows=1 width=262) (actual time=0.000..0.000 rows=1.00 loops=200)
              Cache Key: t.driver_id
              Cache Mode: logical
              Hits: 187  Misses: 13  Evictions: 0  Overflows: 0  Memory Usage: 2kB
              Buffers: shared hit=26
              ->  Index Scan using drivers_pkey on drivers d  (cost=0.14..0.40 rows=1 width=262) (actual time=0.003..0.003 rows=1.00 loops=13)
                    Index Cond: (driver_id = t.driver_id)
                    Index Searches: 13
                    Buffers: shared hit=26
Planning Time: 0.273 ms
Execution Time: 0.465 ms
```

## Reflection

The first thing I learned from the plan is that a join's cost depends on what it's joining, not just whether the SQL says `INNER JOIN`. For this report PostgreSQL scans 200 trips and hashes 30 riders, then looks up drivers through their primary-key index. It only has to do 13 actual driver index searches because Memoize reuses 187 earlier results. That fits this dataset: 200 trips are spread across just 13 drivers.

If the platform had millions of trips and thousands of drivers, that pattern could change. Repeating the driver lookup might stop being such a bargain if every few trips referred to a different driver, and PostgreSQL might choose to hash the driver table instead. If both inputs became large and were already sorted on their joining keys, a Merge Join could make sense. New indexes could also change the choice, especially for a report limited to one driver or rider. For the report here, which reads every trip, an extra index would not automatically be better than a scan.

The plan also includes a Sort of all 200 rows, which fits in 46 kB now but might need disk space as the history grows. I'd use `EXPLAIN` again after a substantial change rather than assume today's plan will stay the best one.
