# Unit 4 Write-ups

## Task 4.1: Measure the platform

### Who would act on the per-driver breakdown?

A driver operations manager: the person who looks after drivers day to day and decides who gets a check-in, some coaching, or a closer look. The per-driver numbers (trips, no-shows, and how often a driver's trips end in a no-show) are the list they'd work from.

### What the totals and averages hide

**Averages hide the spread.** The platform's average fare is $18.14, which sounds like a typical trip. It isn't. Of the 200 trips, 34 were cancelled and have $0 recorded fares, and those $0 trips drag the average down. Among the 166 trips with positive recorded fares, the average is $21.86, and fares run anywhere from $4.65 to $70.86.

The same thing happens driver by driver. Driver 11 has the lowest average fare on the platform at $11.94, but 5 of their 16 trips had $0 recorded fares. On the other 11 they average about $17. At the other end, driver 4 has the highest average among positive-fare trips ($29.23), but that's built on just four trips, so a single long ride moves it a lot. An average on its own doesn't tell you how many trips are behind it or what's mixed in.

**Counts hide who is being counted.**

- Our trips-based results show 13 drivers, but the drivers table has 15. Drivers 14 and 15 haven't had a single trip, so they disappear from every breakdown by driver.
- A percentage can sit on a tiny count. Driver 4's no-show rate is 16.7%, which sounds alarming, but it's one no-show out of six trips. That's why, when I compared drivers by no-show rate, I only included drivers with at least 13 trips. That first-quartile cutoff currently leaves 10 of the 13 drivers with trips. Drivers 1, 4, and 13 (11, 6, and 11 trips) were set aside.
- The same problem gets worse when you split the data further. Breaking each driver's trips out by region creates 38 small groups, and 12 of them have three trips or fewer. One driver had a single no-show on two trips in the North, which works out to 50% on paper. Numbers like that shouldn't be over-read. The quartile screen is not a statistical significance test, and ties at the cutoff are kept.

### Two ways of looking at "region"

The data doesn't define regions, so I tried two: where the trip starts, and where the driver is based. The recorded pickup location is my main view, since it shows where a trip was supposed to start and where a regional manager might investigate. Where the driver is based would be the better view if regional managers are in charge of the drivers who live in their area, but it's a weaker lens here. Only one driver is based in Danang, so "Danang drivers" is really just driver 2. I group Hanoi/Haiphong as North, Danang/Hue as Central, and Saigon as South. Only 44 of 200 trips share the driver's home city, and 67 share the broader home region.

Because each driver has a single home city, the home-region and home-city queries group that driver's **whole trip record** by home location, even when pickups happened elsewhere. A recorded pickup location also does not establish that the driver physically arrived there.

### What I'd want to see next

- **A longer history.** All of our trips are from 2023. With one year we can't tell whether a driver with a high rate is having one bad stretch or has a habit.
- **Whether the driver actually showed up.** The data only records that the rider was a no-show. It doesn't say how long the driver waited or whether they reached the pickup spot. That would separate a real no-show from a trip that was labeled that way by mistake.
- **The payout rule's cutoff.** We still don't know what no-show rate triggers a freeze. With it, we could say whether any driver actually crosses the line.
- **More trips for the lowest-volume drivers** (1, 4, and 13), so their rates mean something.

## Task 4.2: Build the breakdown

### Part A: Two questions, side by side

The query answers two questions in a single result:

1. **How many trips did each driver have?**
2. **How many of those trips ended in a rider no-show?**

Seeing both numbers together matters because the percentage alone can mislead. Driver 4's rate (16.7%) looks about as bad as driver 2's (18.8%), but driver 2 had 3 no-shows on 16 trips and driver 4 had 1 on 6. The result includes all 13 drivers and flags the small samples (drivers 1, 4, and 13) instead of hiding them.

What it shows is that no-shows are thin. Four drivers (5, 8, 10, and 13) had none, and seven had exactly one (1, 4, 6, 7, 9, 11, and 12). Driver 3 had two and driver 2 had three. The three highest rates belong to drivers 2, 4, and 3, at 18.8%, 16.7%, and 15.4%.

**Does driver rating explain it?** Not from these data. I put each driver's rating next to their numbers to check. The three drivers with the highest no-show rates are rated 4.94, 4.88, and 4.91, which are among the best ratings on the platform. The two lowest-rated drivers *with trips* (6 and 7, both 3.65) each had one no-show, rates of 4.8% and 5.6% that sit close to the platform's 6.0%. Drivers 2 and 13 even share the same 4.94 rating, but one had three no-shows and the other had none. With only 12 no-shows I wouldn't call it proof, and no simple association is apparent. Driver 14 is rated 3.63 but has no trips, so is absent from this comparison.

### Part B: Subtotals and a grand total

**Who needs it.** A regional manager, one example of the leaders this report is for. They're responsible for a region's results, not for individual drivers or trips, so a long list of drivers is just noise to them. They need one line for their region and one line for the platform to compare it to. In the output, each row marked "Regional subtotal" is one region, and the single row marked "Grand total" is the whole platform.

**What the grand total adds.** It's the yardstick for the region rows. The platform-wide no-show rate is 6.00% (12 no-shows on 200 trips). Against that, the North at 7.79% (6 on 77 trips) is above the line, Central at 6.02% (5 on 83) is right on it, and the South at 2.50% (1 on 40) is well below. Without the total, those are three unrelated percentages. With it, a leader can tell whether the North has a problem of its own or whether the whole platform does. The total also shows how small the whole problem is. There are only 12 no-shows, so any regional effort should be sized with that in mind.

Fares and driver ratings don't explain the differences between regions either. The average fare on trips with positive recorded fares is $21.19 in Central, $21.78 in the North, and $23.22 in the South, against $21.86 for the platform as a whole. (These averages exclude $0 fares; a positive fare does not prove that payment was collected.) Average driver ratings, weighted by each driver's trip count, are similar everywhere: 4.35 in the North, 4.41 in Central, and 4.46 in the South, against 4.40 overall. The regions also bring in very different totals, with $1,398.31 in Central, $1,394.11 in the North, and $835.77 in the South, out of $3,628.19 on the platform. That's mostly a matter of size, since the South has about half as many trips (40) as the others.

**What a region can hide.** I ran the same breakdown by city. Central looks average at 6.02%, but that's two very different cities. Hue is the highest on the platform at 10.00% (4 on 40 trips) and Danang is the lowest at 2.33% (1 on 43). The regional numbers also rest on very few no-shows (6, 5, and 1), so a single trip either way would noticeably shift them, especially in the South.

### Part C: The question the pipeline answers

**Among our busier drivers, what is the recorded no-show rate, and which have higher rates?**

It works in three steps. First it totals trips and no-shows for every driver. Then it keeps only the busier ones, meaning drivers with more trips than the average of about 15.4 per driver. That's 8 drivers (2, 5, 6, 7, 8, 10, 11, and 12). Their combined record is 7 no-shows on 145 trips, so the baseline is **4.83%**. Finally, it compares each of those drivers to the baseline.

Driver 2 is the one that stands out. They had 3 no-shows versus about 0.77 at the group benchmark, putting their rate 13.92 percentage points above it. That benchmark includes driver 2's own trips and is not a prediction. Drivers 11, 12, and 7 are only 0.7 to 1.4 points above, which a trip or two can explain. Driver 6 sits right on the baseline, and drivers 5, 8, and 10 had none.

This "busier drivers" group is a different idea from the 13-trip cutoff in 4.1. That cutoff asks "which drivers clear a minimum volume screen?" This one asks "which drivers are busy enough to set the benchmark?" Every driver in this group clears the 13-trip cutoff, but not the other way around. That also means drivers 3 and 4 aren't in this comparison, so it doesn't judge them.


### Supplementary checks (D1-D2)

Riders 1 and 21 each had two recorded no-shows, involving two different drivers apiece. By surge multiplier, the counts were 3/99 at 1.00, 7/46 at 1.25, 0/29 at 1.50 and 2/26 at 2.00. These are prompts for follow-up, not explanations of rider behavior or evidence of causation.

## Reflection

Conditional aggregation lets me get "how many trips" and "how many no-shows" out of a single read of the trips table. A CASE expression sits inside the count, so every row is looked at once and counted toward whichever totals it belongs to. The alternative is two separate queries, one for all trips and one with a filter for no-shows. Depending on the database plan, that may require two scans and matching up the two grouped results by driver.

With 200 rows nobody would notice the difference. With a million, reading the table can be expensive in disk, memory, and processing time. Two separate queries may duplicate that work, depending on indexes and the query plan. In the single-query version, another outcome (disputed trips, say) can usually be added as one more CASE column.

There's also a correctness benefit. Two separate statements can see different snapshots if a new trip arrives between them, depending on transaction settings. One statement calculates both counts from a consistent snapshot, so the rate is internally aligned.
