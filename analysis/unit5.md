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

**[Add from the EXPLAIN output for the final `q5_1.sql` Q1 query.]** The repository material I have does not include the execution plan for the final version of that SELECT, so I can't reliably name the chosen algorithms yet. Record each join node shown in the actual output (for example, **Hash Join**, **Nested Loop**, or **Merge Join**) and any **Sort** node. An older plan for a shorter SELECT isn't enough to verify what PostgreSQL selected for this one.

### 3. What in the execution plan helps explain those choices?

The first things I'd look at are the estimated **row counts**, **costs**, and whether PostgreSQL uses a **Seq Scan**, **Index Scan**, or **Sort**. The tables are small right now: **200 trips, 30 riders, and 15 drivers**. The supplied dataset has primary-key indexes for the rider and driver IDs, but no separate indexes on `trips.rider_id`, `trips.driver_id`, or `trips.requested_at`. A Hash Join can make sense for small tables joined on matching IDs, while a Nested Loop can make sense if the inner lookup uses an index. The `ORDER BY` can also require sorting. Those are explanations to check against the plan, not claims about nodes I haven't seen.

**[After running EXPLAIN, add one specific sentence naming the actual scan/index and sort nodes, with their estimated rows or costs. Also paste the complete plan below or reference its screenshot.]**

#### Full PostgreSQL execution plan

```text
[Paste the complete output from EXPLAIN on Task 5.1 Q1 here.]
```

### 4. Why is it useful to understand the join algorithms?

A query giving the right answer today doesn't mean it will stay quick when the platform gets bigger. The plan shows **how PostgreSQL gets that answer**, not just what comes back. It can help us spot unnecessary scans, lots of repeated lookups, an expensive sort, or a join that creates far more rows than expected. It also helps us decide whether an index or a query rewrite would actually help, instead of adding things just because they sound faster.

### 5. What changes might make a different algorithm more appropriate?

More trips, different numbers of matching rows, or new indexes could all change the plan. If we added indexes on the trip table's driver and rider IDs, PostgreSQL might find indexed lookups more attractive for a smaller filtered report. For a very large report that joins most trips, scanning and hashing could still be cheaper than doing millions of separate lookups. A Merge Join could be worth considering if both inputs were available in useful order. Sorting by request time could also become more expensive as the trip table grows, especially if it no longer fits in memory. PostgreSQL chooses based on its cost estimates, so adding an index doesn't guarantee a specific join type.

### Reflection (150–250 words)

Right now the three-table report is working with 200 trips, 30 riders, and 15 drivers. At that size, PostgreSQL can afford to scan a small table or do repeated lookups without much trouble. But I wouldn't assume the same approach would make sense after the platform grows to a million trips. The number of rows, how many matches each join finds, and the indexes available can all change which algorithm costs the least.

For example, the supplied trip table doesn't have separate indexes on its rider and driver foreign keys. Adding them could make indexed lookups more useful, especially if a report is narrowed down to a few drivers or riders. A Nested Loop might then be a good fit. If a report needs almost every trip, a Hash Join could still be faster because it can process large sets without doing an index lookup for every trip. A Merge Join might make sense when both sides are already sorted by the join key. The request-time sort could become another bottleneck as the output grows.

What matters is checking the actual execution plan rather than assuming that one algorithm is always best. I'd compare estimated rows and costs, and use EXPLAIN ANALYZE for a read-only query if I needed to see what really happened.
