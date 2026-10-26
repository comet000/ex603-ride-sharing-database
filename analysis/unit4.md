# Unit 4 Write-ups: From Rows to Insight

## Task 4.1: Measure the platform

### Who would use the per-driver breakdown?

A **driver operations manager** would use the per-driver results to decide whose trip history merits a check-in, a little more context, or a closer review. A **regional director** or **regional operations leader** would want the same information organized by location, so they could see where service problems might need attention. **Trust and Data leadership** would check that the numbers are fair and calculated consistently. **Rider support leadership** would want to know whether the people requesting the trips, and their experiences at pickup, tell a different part of the story. And anyone overseeing **driver bonuses or payouts** would need to know what the policy actually measures before using a failure rate to make a payment decision.

These leaders wouldn't necessarily use the same report. A director accountable for service in the North needs pickup-location figures; a manager responsible for drivers *based* in the North might need a different breakdown. The common starting point is that we're counting **trips recorded as rider no-shows**. We can associate those trips with drivers, but we can't assume those drivers caused the riders not to appear.

### What the platform totals and averages hide

**An average can hide a very mixed set of trips.** The 200 recorded trips have a total fare amount of **$3,628.19** and an average fare of **$18.14**. Fares range from **$0.00 to $70.86**. The zero isn't missing data: the fare field is populated on every trip, and all **34 cancelled trips have a recorded fare of $0**. The remaining **166 trips**, which were completed or disputed, have positive recorded fares. Their average is **$21.86**, with a range of **$4.65 to $70.86**. The fare total remains $3,628.19 when the $0 records are excluded, because removing zeros doesn't change the sum.

Here's why that matters:

| Which trips are counted? | Trips | Average recorded fare | What the figure means |
|---|---:|---:|---|
| All trips | 200 | $18.14 | Includes cancellations recorded at $0 |
| Trips with a positive fare | 166 | $21.86 | Describes fare amounts when a positive amount was recorded |

The trip-status check also shows **156 completed**, **34 cancelled**, and **10 disputed** trips. All $0 fares are in the cancelled group; the other two groups have positive recorded fares. That makes the $0 minimum understandable, rather than an unexplained anomaly. It does **not** prove every positive fare was collected or that every disputed fare will stand.

Averages conceal differences between drivers, too. **Driver 11** has the lowest average recorded fare across all trips, **$11.94** on 16 trips. Five of those trips have a $0 fare; the other 11 average **$17.37**. **Driver 4**, meanwhile, has the highest average positive fare, **$29.23**, but that comes from only four positive-fare trips. Driver 5 has the highest overall average fare, **$23.06**. These are all correct averages; without the underlying counts and trip outcomes, though, they can give quite different impressions of a driver's record.

**A count can hide who is included.** All **30 distinct riders** appear in the trip records. The Unit 3 setup check found **15 registered drivers**, but a summary built from `trips` shows only **13 drivers with trips**. Drivers **14 and 15** have none, so they don't appear in those results. That's a consequence of starting from the event table, not evidence that the drivers don't exist. Among the drivers who do appear, recorded trip totals range from **6 trips for driver 4** to **21 trips for driver 6**.

### Why I chose the 25th-percentile threshold

A high no-show percentage can be built on very little information. **Driver 4 has one recorded no-show in six trips (16.67%).** When those trips are separated by pickup region, driver 4's North figures are **one no-show in two trips, or 50.00%**. The arithmetic is right, but I wouldn't want leadership to treat either rate as an established pattern. The driver-by-pickup-region query returns **38 observed groups**, and **12 of them contain three trips or fewer**. The more finely we divide 200 trips, the easier it becomes for one event to dominate a percentage.

The assignment required us to choose a minimum event-count threshold and use `HAVING` to include only drivers who meet it. I chose the **25th percentile of driver trip counts** rather than a fixed number.

I chose this approach for three reasons. First, the cutoff **recalculates automatically as the data changes**. Second, **stakeholders can adjust the percentile based on their operational expertise**. For example, using the 10th percentile would generally include more drivers. Third, **deciding on a threshold after examining the failure rates could introduce bias** by influencing which drivers qualify for the comparison. Using the distribution of trip counts provides a cutoff without choosing one to fit particular no-show results.

For this dataset, the cutoff is **13 trips**. **10 of the 13 drivers with recorded trips** meet it, while drivers **1, 4, and 13** fall below it, with 11, 6, and 11 trips respectively. The screen excludes the smallest trip histories without removing most drivers from the comparison. Because drivers tied at the cutoff are included, it doesn't necessarily exclude exactly 25% of drivers.

The **13-trip cutoff is not a permanent or statistically proven minimum**. It is the current result of the percentile rule, and a driver's recorded failure rate can still be unstable above it. The later side-by-side query **shows all 13 drivers with trips** and flags the three smaller histories instead of hiding them. One view applies the trip-count screen; the other shows the full context, including who falls below that screen.

### Why I kept four views of “region”

The dataset contains **pickup city** and **driver home city**, but no official region field and no explanation of how the company assigns regional responsibilities. I grouped **Hanoi and Haiphong as North**, **Danang and Hue as Central**, and **Saigon as South**. Those are *analytical groupings I defined*, not company-approved administrative regions.

I then used both location ideas, at two levels of detail:

| View | What it answers | Who might need it |
|---|---|---|
| **Driver × pickup region (primary)** | In which broad areas were each driver's trips and no-shows recorded? | A director responsible for service originating in that area |
| **Driver × pickup city** | Does a broad regional figure hide important differences between cities? | City and regional operations teams |
| **Driver × home region** | How would the same drivers' overall results appear under a home-region management structure? | A leader responsible for drivers based in a region |
| **Driver × home city** | How would those driver histories look if responsibility were assigned by home city? | A city-based driver management team |

**Pickup region is my primary answer** because it describes where trips were scheduled to start. But the alternative isn't redundant if the business assigns responsibility by driver home location. For example, **driver 2 is based in Danang**, but their **three no-shows** were recorded on pickups in **Hue and Haiphong**. The home-city view puts all three in Danang's driver group; the pickup-city view places the events where the trips were supposed to begin. Neither arrangement tells us, by itself, who was at fault.

The distinction affects a lot of records: only **44 of 200 trips** started in a driver's home **city**, and **67 of 200** started in their home **region**. Also, each driver has one recorded home city, so the home-location queries reorganize the driver's *whole trip history*. They do not show that the driver performed differently from one pickup location to another. The pickup-based queries can make that comparison because each driver's trips may span several places.

I didn't apply the quartile-based trip-count screen to the two-dimension summaries. Regional leaders need to see the observed driver-and-location combinations, including small ones; the query displays the trip count beside every rate so those small groups can be recognized rather than mistaken for reliable trends.

### What I'd want to see next

- **More trip history beyond 2023**, especially for drivers with only a handful of trips. This would show whether their observed rates settle down, remain unusual, or change over time. A *relative* percentile screen will always leave some drivers below its cutoff; the point of collecting more history is better evidence, not guaranteeing that everyone eventually passes that screen.
- **Pickup-arrival and waiting evidence**, such as arrival confirmations, how long a driver waited, and rider-driver messages. The table has the cancellation label but doesn't explain what actually happened at the pickup. This would help distinguish a genuine rider absence from a potentially incorrect classification.
- **Driver availability or working hours**, so trip volume isn't automatically equated with being busier, more productive, or more committed. The dataset counts recorded trips but not how long drivers were available to take them.
- **The real bonus or payout rule**, including whether a rider no-show should count against a driver and whether any rate triggers a review or freeze. Without that rule, we can describe the records but cannot justify a payout decision.
- **More detailed support or complaint evidence from both sides**, to understand whether recurring problems relate to riders, pickup instructions, location-specific operations, or recording practices. The current trip fields cannot settle those explanations.

## Task 4.2: Build the breakdown leadership asked for

### Part A: Two questions, answered side by side

The conditional-aggregation query answers two questions in the **same driver-by-driver result**: **How many trips does each driver have?** And **how many of those trips were recorded as rider no-shows?** A driver with zero no-shows still appears because the query counts all trips, rather than filtering the whole table down to failures first. It also shows the no-show percentage, driver rating, and a small-sample flag.

Here's the full picture of the no-show counts. The **13-trip screen** makes the three smaller histories easy to spot, but it is not a performance grade:

| Driver | Trips | Rider no-shows | Rate | 13-trip screen |
|---|---:|---:|---:|---|
| 2 | 16 | 3 | 18.75% | ✓ Meets |
| **4** | **6** | **1** | **16.67%** | **⚠ Below (small sample)** |
| 3 | 13 | 2 | 15.38% | ✓ Meets |
| **1** | **11** | **1** | **9.09%** | **⚠ Below (small sample)** |
| 9 | 14 | 1 | 7.14% | ✓ Meets |
| 11 | 16 | 1 | 6.25% | ✓ Meets |
| 12 | 17 | 1 | 5.88% | ✓ Meets |
| 7 | 18 | 1 | 5.56% | ✓ Meets |
| 6 | 21 | 1 | 4.76% | ✓ Meets |
| 5 | 18 | 0 | 0.00% | ✓ Meets |
| 8 | 20 | 0 | 0.00% | ✓ Meets |
| 10 | 19 | 0 | 0.00% | ✓ Meets |
| **13** | **11** | **0** | **0.00%** | **⚠ Below (small sample)** |

These are **13 drivers with recorded trips**, not all 15 registered drivers. Four drivers (**5, 8, 10, and 13**) have no no-shows, seven have exactly one, driver 3 has two, and driver 2 has three. A percentage-only ranking would make **driver 4's 16.67%** look almost as concerning as **driver 2's 18.75%**. But driver 4 had **1 no-show in 6 trips**, while driver 2 had **3 in 16 trips**. Both rates merit context, and the smaller history for driver 4 makes its percentage especially sensitive to a single event.

The driver ratings provide another useful cross-check. Drivers **2, 4, and 3** have recorded ratings of **4.94, 4.88, and 4.91**, placing all three among the **five highest-rated drivers with recorded trips**, despite their high observed no-show percentages. Drivers **6 and 7**, the lowest-rated drivers *with trips* at **3.65**, each have just one no-show. Driver **13** shares driver 2's **4.94** rating but has no no-shows. That doesn't prove ratings have no relationship to service problems; it means these records don't offer a straightforward ratings-based explanation for the no-show pattern. Driver **14**, whose rating is lower still at **3.63**, has no recorded trips and therefore no meaningful trip-based no-show rate.

Just as importantly, these records identify **drivers associated with rider no-show events**. They don't establish that a driver caused a rider not to appear.

### Part B: Why leadership needs subtotals and a grand total

A **regional director** needs one line for their region and one for the platform, rather than dozens of small driver-and-location groups. The same view is useful to **regional operations, Trust and Data, rider support, and payout leadership**, though each team may make a different decision with it. The first `ROLLUP` provides **three regional subtotal rows** and **one platform grand-total row**. It leaves out the city-by-region breakdown in this particular result, keeping the broad comparison easy to read. That doesn't make city-level information unnecessary; a second `ROLLUP` provides those summaries separately. Neither query displays individual trip or driver records.

| Pickup region | Trips | Rider no-shows | No-show rate |
|---|---:|---:|---:|
| North | 77 | 6 | 7.79% |
| Central | 83 | 5 | 6.02% |
| South | 40 | 1 | 2.50% |
| **Platform** | **200** | **12** | **6.00%** |

The **grand total supports a decision the individual region rows can't support on their own**: whether leadership should begin with a targeted geographic review or consider a platform-wide process problem. North's **7.79%** is above the platform's **6.00%**, Central is almost equal to it, and South's **2.50%** is lower. That gives leaders a useful starting point for questions, **not proof** that any region is consistently worse. There are only 12 no-shows in the entire dataset, and the South's rate comes from a single event.

The **separate city-level `ROLLUP`** is also an aggregated view. It shows why the regional average can conceal differences between cities:

| Pickup city | Region used here | Trips | Rider no-shows | No-show rate |
|---|---|---:|---:|---:|
| Hue | Central | 40 | 4 | 10.00% |
| Hanoi | North | 38 | 3 | 7.89% |
| Haiphong | North | 39 | 3 | 7.69% |
| Saigon | South | 40 | 1 | 2.50% |
| Danang | Central | 43 | 1 | 2.33% |

**Hue and Danang** sit in the same analytical region yet have very different observed rates. Central's overall **6.02%** would hide that contrast. Looking more closely at Hue is sensible; claiming that Hue has an established ongoing problem would go beyond these few events. City and regional totals answer complementary questions, and the five city rows reconcile to the same **200 trips and 12 no-shows** as the regional and platform totals.

The `ROLLUP` queries also return **three additional measures**: total recorded fares, average fare on positive-fare trips, and average recorded driver rating. I show them separately so the no-show counts and rates in the first table stay easy to read:

| Pickup region | Recorded fare total | Average positive fare | Average recorded driver rating* |
|---|---:|---:|---:|
| North | $1,394.11 | $21.78 | 4.35 |
| Central | $1,398.31 | $21.19 | 4.41 |
| South | $835.77 | $23.22 | 4.46 |
| **Platform** | **$3,628.19** | **$21.86** | **4.40** |

*The driver-rating average is weighted by recorded trips. A driver who appears on more trips contributes their rating more times; this is not a simple average of distinct drivers' ratings. Average positive fares exclude trips recorded at $0, and recorded fares are not proof of collected payments.*

The regional fare totals differ, but so do the trip counts: South has **40 trips**, compared with **77** and **83** in the other regions. The fare and rating figures are useful background for a leader trying to understand an area, not evidence that either of them caused the observed no-show differences.

### Part C: What the multistep comparison tells us

**What baseline no-show rate do drivers with above-average trip counts have, and how does each driver in that group compare with it?**

For this analysis, **high volume means having more recorded trips than the average driver with a trip history**. It is based on trip count, not hours available, time spent driving, or fare revenue. The query first counts trips and no-shows by driver. The average among the 13 drivers with recorded trips is **15.38 trips**. Eight drivers exceed that average: **2, 5, 6, 7, 8, 10, 11, and 12**. Together, they have **145 trips and seven rider no-shows**, producing a **4.83% baseline no-show rate for the high-volume group**.

The comparison reveals more than one type of result:

| Driver | Trips | No-shows | Driver rate | Compared with 4.83% group rate |
|---|---:|---:|---:|---|
| **2** | **16** | **3** | **18.75%** | **Above: +13.92 percentage points** |
| 11 | 16 | 1 | 6.25% | Above: +1.42 points |
| 12 | 17 | 1 | 5.88% | Above: +1.05 points |
| 7 | 18 | 1 | 5.56% | Above: +0.73 points |
| 6 | 21 | 1 | 4.76% | Below: 0.07 points |
| 5 | 18 | 0 | 0.00% | Below: 4.83 points |
| 8 | 20 | 0 | 0.00% | Below: 4.83 points |
| 10 | 19 | 0 | 0.00% | Below: 4.83 points |

**Driver 2 stands out in this group.** Their **18.75%** rate is **13.92 percentage points above the 4.83% baseline**. If we apply that baseline to driver 2's 16 trips, it corresponds to **about 0.77 no-shows on average**, or fewer than one. The actual record contains **3 no-shows in those 16 trips**. The 0.77 figure illustrates the baseline over the same number of trips; it is not a prediction, and no-show events cannot occur in fractions. Driver 2's trips are included in the baseline itself, so this is not an independent standard or evidence that the driver caused the incidents.

The other drivers are closer to the baseline or recorded zero events. **Drivers 3 and 4 are not part of this high-volume group** because they did not exceed the average of 15.38 trips. In the separate Task 4.1 **quartile-based screen**, driver 3 meets the current 13-trip cutoff and driver 4 falls below it. The quartile screen limits the influence of very small trip histories; the above-average rule defines the group used to calculate the **4.83% baseline**. Neither method establishes fault or statistical significance.

### Additional checks: what about the riders and surge multipliers?

Since the failure we are auditing is a **rider no-show**, a driver-only breakdown might miss patterns associated with the riders. That led me to check whether any riders appeared on multiple no-show trips and, if so, whether those trips involved the same or different drivers.

| Rider ID | All recorded trips | No-show trips | Different drivers on those no-show trips |
|---|---:|---:|---:|
| 1 | 13 | 2 | 2 |
| 21 | 8 | 2 | 2 |

Together, those two riders appear on **four of the 12 no-show trips (33.33%)**. This doesn't prove a rider did something wrong; a trip may have been misclassified, and we lack pickup-arrival and communication evidence. But it shows why leadership should consider **rider-side records** before treating a driver-associated rate as the driver's fault. These rider IDs are here as query findings, not as recommendations for punishment.

I also grouped trips by their **surge multiplier** to see whether no-show rates looked different under different recorded pricing conditions:

| Surge multiplier | Trips | Rider no-shows | No-show rate |
|---|---:|---:|---:|
| 1.00 | 99 | 3 | 3.03% |
| 1.25 | 46 | 7 | 15.22% |
| 1.50 | 29 | 0 | 0.00% |
| 2.00 | 26 | 2 | 7.69% |

The **1.25** group has the highest observed percentage and accounts for **seven of the 12 no-shows**. That's worth checking in a larger history, but the rates don't move steadily upward with the multiplier, and there are only 12 failures altogether. The table doesn't establish whether price, timing, pickup location, driver assignment, rider history, or chance produced the differences. So these are **investigative leads**, not explanations or a basis for changing surge pricing.

Taken together, the results point to a practical next step for leadership: **review the specific no-show trips associated with drivers 2 and 3, investigate their pickup locations, and involve rider support to understand what happened without assuming driver responsibility.** The platform's **6.00%** rate was established in Unit 3; the new contribution here is identifying which records deserve a closer look.

## Reflection

Conditional aggregation gives me two related answers in one result instead of making me piece them together afterward. Imagine checking a list of trips for each driver and keeping two tally marks: one for **every trip**, and another whenever the trip was marked **“Rider no show.”** A `CASE` expression inside `COUNT` does that work. The result gives leadership both the total number of trips and the no-show count beside the same driver, so a high percentage isn't floating around without its context.

I could run two filtered queries instead: one counting all the trips and a second counting only the no-shows. But then I'd have to line the two result sets up by driver. A driver with **no no-shows** might not appear in that second list at all, which makes it easy to accidentally leave them out or match the wrong figures. The combined query keeps the comparison together.

For our **200 trips**, either approach is manageable. At **a million rows**, extra scans, grouping, and matching may use considerably more computer time and memory, though the exact difference depends on indexes and the database's execution plan. The one-query approach is also easy to extend: if leadership later wants disputed trips alongside no-shows, I can add another conditional count instead of another separate report. Because both counts come from the same query, they're also based on the same view of the data, rather than risking separate reports taken at different moments.
