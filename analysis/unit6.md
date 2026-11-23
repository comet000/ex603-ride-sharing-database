# Unit 6 Write-ups: Analytics

**Theme:** Ride Sharing  
**Database:** `ex603_data`  
**Failure definition:** `cancellation_reason = 'Rider no show'`

The SQL is in [`queries/unit6/`](../queries/unit6/). As in Units 3 through 5, a rider no-show is a recorded **trip outcome**, not proof that the assigned driver caused it. Drivers **2 and 3** remain priorities for reviewing individual trips; Driver **4** remains a monitoring case because their history is small.

## Task 6.1: Compute across a window without collapsing

### 1. Individual events versus a group average

**Question:** *Which individual trip fares are unusually high or low compared with the average for their own driver, and by how much?*

A driver-level average alone cannot identify a particular unusual trip. Query **1a** in [`q6_1.sql`](../queries/unit6/q6_1.sql) uses `AVG(fare_amount) OVER (PARTITION BY driver_id)` to keep **all 200 trip rows**, with each fare, the driver's average, and the difference on one row. Driver averages range from **$11.94 (Driver 11)** to **$23.06 (Driver 5)**. The most extreme positive deviation is **Trip 43**: Driver 4's **$70.86** fare is **$51.37** above that driver's **$19.49** average. At the other end, a $0 cancellation for Driver 5 is **$23.06 below** their average. These are unusual *recorded fares*, not proven pricing mistakes.

Query **1b** uses `GROUP BY driver_id` and returns **13 rows**, one for each driver with trips. It loses trip IDs, individual fares, and the ability to identify the deviations. Joining the 13 grouped averages back to `trips` can restore the 200 records; the alternative we actually ran restored the averages but did not calculate deviations. We could add that expression after the JOIN, but it takes an extra step. The window function gives the comparison directly. Neither method creates an average for Drivers **14 and 15**, who have no trip records; Unit 5 addressed why those drivers disappear from event-based views.

Including all statuses is deliberate. All **34 cancelled trips** have $0 recorded fares, which lowers the average fare **per request**. Dropping them would answer a different question (fare for non-cancelled trips) and could make the platform look stronger on a per-request measure. Recorded fares are not necessarily payments collected.

### 2. Ranking functions and the platform feature

**Feature:** A driver **trip-activity leaderboard** that shows each driver's position by recorded trip requests. This is not a quality score, and the counts include cancelled requests because the assignment asks us to rank the events in the dataset.

Driver **6** leads with **21 trips**; Driver **4** has **6**, the fewest. The three tied pairs are Drivers **5 and 7** (18 trips), **2 and 11** (16), and **1 and 13** (11). Query **2** displays all three ranking methods together:

| Function | Drivers 5 and 7 | Next driver: 12 (17 trips) | Interpretation |
|---|---|---|---|
| `ROW_NUMBER()` | 4th and 5th | 6th | Forces different positions for equal trip counts |
| `RANK()` | Both 4th | 6th | Keeps the tie and skips the occupied position |
| `DENSE_RANK()` | Both 4th | 5th | Keeps the tie without gaps |

**I'd publish `RANK()` for a competitive leaderboard.** Both tied drivers are shown as *tied for fourth*, and the next position reflects that two drivers share fourth. `DENSE_RANK()` would be a reasonable choice for **tiers** based on distinct activity levels. `ROW_NUMBER()` would be appropriate only where a genuinely unique ordering is needed and the tie rule is disclosed. None of these functions by itself establishes a fair bonus policy or a strict five-person payout cap.

**Tie-breaker choice:** `ROW_NUMBER()` now orders equal counts by `driver_id` so the same records produce the same row numbers in the stakeholder report. Without that secondary key, Drivers 5 and 7 might swap positions when the query is rerun. The driver ID is **not evidence of better performance**; the forced distinction remains the weakness we are demonstrating. We intentionally did **not** add `driver_id` to `RANK()` or `DENSE_RANK()`, because doing so would eliminate the genuine ties.

Query **3** makes the related `NTILE(4)` limitation visible. The 13 drivers are divided into buckets of **4, 3, 3, and 3**. Drivers **5 and 7**, tied at 18 trips, land in quartiles **1 and 2**; Drivers **2 and 11**, tied at 16, land in **2 and 3**. I added `driver_id` to `NTILE()` so the *assignment* of the two tied drivers is reproducible. Without it, which individual driver receives the better quartile could change between executions. The extra key does **not** stop `NTILE()` from separating equally active drivers. For actual rewards, the platform would need an explicit policy that respects ties rather than treating an ID-based split as merit.

## Task 6.2: Compare each row to its neighbors

### 1. What would a large fare delta mean, and what should the team do?

Query **1** in [`q6_2.sql`](../queries/unit6/q6_2.sql) compares Driver **2**'s consecutive recorded fares using `LAG()` and `LEAD()`. The driver has **16 trips** and **15 trip-to-trip changes**: **7 increases, 7 decreases, and 1 unchanged**. The biggest increase is **+$27.98** on Trip **18** (from $19.83 to $47.81), which had a **2.00x surge multiplier**. The biggest decrease is **-$32.59** on Trip **23**, the next recorded trip for that driver. The last trip, **26**, fell **$20.29 to $0** and was recorded as a rider no-show.

Four trips (12, 14, 21, and 26) have $0 fares: **three rider no-shows and one “Driver unavailable” cancellation**. A large delta is therefore a reason to inspect the two trips, **not** evidence of a pricing error or poor driver performance. First check status and cancellation reason. For completed trips, compare distance and surge; for cancellations, ask Driver Operations and Rider Support to investigate the pickup experience. The dataset does not include the arrival/wait evidence needed to decide who caused a no-show.

**Ordering decision:** All four neighbor calculations now use `ORDER BY requested_at, trip_id` within each driver. `trip_id` is a reproducible tie-breaker if two requests have identical timestamps; without the same ordering in each calculation, the displayed “previous fare” and the delta could refer to different trips. This is different from the intentional tie-policy demonstration in Task 6.1: here the calculations must agree about which row is adjacent. The dataset has no identical timestamps for Driver 2, so the present results do not change. `requested_at` remains a timestamp, and all fares remain numeric rather than being converted to display strings.

### 2. Why does a running total answer something a plain `SUM()` cannot?

Plain aggregates tell us the end of the story: `COUNT(*)` gives **200 requests**, and `SUM(fare_amount)` gives **$3,628.19 in recorded fares** for 2023. It cannot show *when* the totals accumulated. Queries **2a and 2b** keep one row per month and use `SUM(...) OVER (ORDER BY month_start ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` to track progress toward **illustrative**, not company-approved, annual targets.

| Point in year | Running trips | Of 180 illustrative trips | Running recorded fares | Of $4,000 illustrative fares |
|---|---:|---:|---:|---:|
| End of June | 101 | 56.11% | $1,766.77 | 44.17% |
| End of September | 152 | 84.44% | $2,770.88 | 69.27% |
| End of November | 184 | 102.22% | $3,356.95 | 83.92% |
| End of December | **200** | **111.11%** | **$3,628.19** | **90.70%** |

I chose **180 requests** because it is 15 per month, and **$4,000 in recorded fares** as a simple practice benchmark near the dataset's scale. The assignment asks us to choose a target; **neither benchmark should be presented as an actual company goal or a recommended performance threshold**. The trip target was passed in November, while the fare target was never reached. A running report shows that difference developing throughout the year. Cancelled $0 trips help explain why more requests do not automatically produce proportionally more recorded fares; they do not establish actual revenue lost.

### 3. Why use a three-month moving average instead of another window?

I used the current month plus the **two preceding monthly rows** (`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`) in queries **2c and 2d**. Three months is long enough to reduce single-month swings without hiding much of our one-year history. A one-month window would not smooth anything; a two-month window would react more strongly to one unusual month; a six-month window would be slow to reflect late-year changes and would leave only seven complete windows.

Among full three-month windows, the trip-count average was lowest in **May (13.00 trips/month)**, highest in **August (18.33)**, and **16.00** in December. For recorded fares, the full-window low was **May ($234.61/month)** and the high was **October ($357.63/month)**; December was **$285.77**. The **December monthly fare total ($271.24) actually rose from November ($215.42)**, even though the three-month average had fallen from its October peak. That is exactly why the window size matters. January's window contains only January, and February's contains two months; those are not full three-month averages.

`ROWS` counts physical rows. When multiple rows share an `ORDER BY` value, a `ROWS` frame can add them one by one; a `RANGE` frame groups equal ordering values as peers and is based on value boundaries. Our monthly series has **one row per month**, so it has no tied month values. But `ROWS` and `RANGE` are only directly comparable when their frame boundaries describe equivalent periods. Also, three monthly rows equal three **consecutive calendar months** here only because Task 6.3 verifies that all 12 months exist.

### 4. What do the gaps mean?

Query **3** identifies **11 gaps of at least 60 whole days without a recorded trip** across **9 of the 13 drivers with trips**. Driver **9** has the longest, **112 days**. Drivers **1 and 3** have two such gaps each. **Eight** gaps follow completed trips, **three** follow cancellations, and **none** follow disputed trips. Driver **11** has an **88-day gap after rider no-show Trip 163**. Conversely, Driver **4**'s no-show Trip **46** is the *trip that ends* a 68-day gap, not the event that started one.

Sparse recorded activity is one plausible explanation, but the query cannot establish the cause. There are just **200 trips across 13 drivers** over the year. A driver might have been offline, received no requests, or had activity omitted from the extract. The available trip records do not distinguish those cases, and seeing trips elsewhere on the platform does not prove that an individual driver's data is complete. I would review the trips around the gaps, especially cancellations, and check driver sign-on, dispatch, and data-pipeline records before concluding there was churn or a logging failure. A cancellation before a long gap does not establish causation. Drivers 14 and 15, with no trips at all, require the separate account-level checks identified in Unit 5.

**Ordering decision:** The gap query uses `requested_at, trip_id` in *every* `LAG()`, so previous trip ID, date, status, and reason all refer to the same recorded predecessor even if timestamps tie. Without the tie-breaker, the selected predecessor could be ambiguous. Its outer `WHERE` runs after the CTE computes the window values, as required.

## Task 6.3: Build the reporting patterns

### 1. What feature would top three power, and why not one or ten?

A **Top Trips Highlight** panel in the driver app or an Operations review screen could show each driver's **three highest recorded fares** as percentages of their own maximum. Query **1** in [`q6_3.sql`](../queries/unit6/q6_3.sql) uses `RANK()` within each driver, `FIRST_VALUE()` for the maximum, and an outer filter for rank three or better.

One trip can be misleading: Driver **4**'s highest fare is **$70.86**, but their second (**$22.77**) and third (**$14.34**) are only **32.13%** and **20.24%** of it. That high fare came from a relatively long **26.11 km** trip with **2.00x** surge. Driver **10** looks different: their third-highest fare (**$34.41**) is **97.73%** of their $35.21 maximum. Three fares provide useful context without filling the screen. Ten would be excessive for drivers with small histories. Driver 4 has only **six trips total**, so top ten would display all six, including cancellations.

I deliberately used `RANK()` rather than `ROW_NUMBER()` for the top-three cutoff. A tie at third place would include *all* trips tied for third instead of arbitrarily excluding one, even if the result exceeds three rows for that driver. No actual top-three ties occur here; **39 rows** are returned. `trip_id` breaks ties only in the final display order, **not inside `RANK()`**, where it would destroy fare ties. `FIRST_VALUE()` already returns the highest fare correctly with the default window frame; the special full-partition-frame warning in our notes concerns `LAST_VALUE()`.

I kept the original final ordering: **third-ranked trips first**, then the smallest percentage of the driver's maximum. That deliberately highlights the largest proportional gaps. The differences are descriptive, not proof of abnormal pricing.

### 2. What does a large month-over-month change mean, and what should we do?

Query **2a** tracks **rider no-shows as a percentage of all monthly trip requests**, rather than comparing raw monthly no-show counts when trip volumes differ. `DATE_TRUNC()` defines calendar months, `LAG()` supplies the previous month's rate, and `NULLIF()` prevents division by zero in the required relative percent-change column. A separate **percentage-point change** column is easier for stakeholders to interpret when rates are low. The `month_check` confirms February through December each follow the previous recorded month; no 2023 month is missing.

| Month | Requests | No-shows | Rate | Change from prior month (percentage points) |
|---|---:|---:|---:|---:|
| Jan | 21 | 2 | 9.52% | N/A |
| Feb | 21 | 0 | 0.00% | -9.52 |
| Mar | 11 | 2 | 18.18% | +18.18 |
| Apr | 11 | 0 | 0.00% | -18.18 |
| May | 17 | 2 | 11.76% | +11.76 |
| Jun | 20 | 1 | 5.00% | -6.76 |
| Jul | 17 | 1 | 5.88% | +0.88 |
| Aug | 18 | 1 | 5.56% | **-0.33** |
| Sep | 16 | 1 | 6.25% | +0.69 |
| Oct | 18 | 0 | 0.00% | -6.25 |
| Nov | 14 | 0 | 0.00% | 0.00 |
| Dec | 16 | 2 | 12.50% | +12.50 |

The monthly rate peaked at **18.18% in March** (2 of 11), reached **0% in October and November**, and rebounded to **12.50% in December** (2 of 16), versus **9.52% in January**. This is **not a consistent month-to-month improvement**. With only 11 to 21 requests per month, one or two incidents move the rate substantially. The rate comparisons are computed before rounding, so August's change is **-0.33 points**, even though subtracting the two displayed rates gives -0.32.

When the prior month has a 0% rate, the relative `pct_change` is **NULL**, because percent growth from zero is undefined; this occurs in **March, May, November, and December**. The percentage-point column remains meaningful in those months. The first month also has a NULL change because there is no earlier observation. Neither situation should be disguised as a numeric zero or a text string.

For a large jump, **check the numerator and denominator first**, then examine the underlying trip IDs and whether the incidents concentrate in particular drivers, riders, or pickup areas. Our optional **2b quarterly** query shows rates of **7.55%, 6.25%, 5.88%, and 4.17%** from Q1 through Q4. The **2c weighted rolling three-month rate** reaches **10.26% in May**, falls to **2.08% in November**, then rises to **4.17% in December**. These longer windows suggest modest improvement in observed rates, but do not establish a reliable lasting trend from just 12 events.

The optional **2d first-half/second-half comparison** adds another caution: Drivers **2, 3, and 4** together recorded **3 no-shows in 17 trips (17.65%) in H1** and **3 in 18 (16.67%) in H2**. Other drivers went from **4/84 (4.76%)** to **2/81 (2.47%)**. These are small groups selected using earlier analysis, not proof of individual responsibility. The optional **Extra 1** query lists all 12 no-show trip IDs, dates, riders, drivers, and pickup cities so operations can investigate rather than imposing an automatic fleet-wide policy. This extends the Unit 4 rider and driver findings without simply recreating its rate leaderboard.

## Reflection (150 to 250 words)

The reporting question I found most useful is: *Which trips stand out from their own driver's average fare, and how did that driver's fare change from the previous recorded trip?* It is not enough to know a driver's average; the team needs the actual trip ID and the neighboring trip to decide what to examine.

A `GROUP BY driver_id` produces 13 averages and collapses the 200 original trip records. It cannot show which particular fare is unusually high or low. I could join those grouped averages back to `trips`, but that adds another step. With `AVG(fare_amount) OVER (PARTITION BY driver_id)`, I can keep each trip and its driver's average together. That reveals Driver 4's $70.86 Trip 43 as $51.37 above their average, while also showing how cancelled $0 trips affect the baseline.

`LAG()` takes the idea further by placing the previous fare beside the current fare, letting us calculate a trip-to-trip difference. `GROUP BY` alone cannot retrieve the previous chronological trip; without a window function, I'd need additional joins or subqueries. I used `requested_at, trip_id` consistently so tied timestamps would not make adjacent-row comparisons disagree. In contrast, I kept equal trip counts tied in `RANK()` because that query has a different purpose: recognizing equal performance. The choice of window and ordering should follow the question, not just the syntax.
