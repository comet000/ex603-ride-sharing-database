# Unit 6 Finding: Is the Rider No-Show Problem Getting Better?

**To:** Platform leadership  
**From:** Trust and Data team  
**Theme:** Ride Sharing (`ex603_data`)  
**Period analyzed:** January to December 2023  
**Failure definition:** `cancellation_reason = 'Rider no show'`

**Summary:** The recorded rider no-show rate **declined modestly by quarter**, from **7.55% in Q1** to **4.17% in Q4**, but **there is no consistent month-to-month improvement**. The year ended with **12 no-shows out of 200 trip requests (6.00%)**. The year contains only twelve no-shows, so the quarterly decline does not establish that the underlying problem is solved. Next quarter, review the specific incidents with both Driver Operations and Rider Support rather than changing payouts or penalizing drivers based on small percentages.

## 1. Is the failure problem getting better or worse?

**Finding:**

**Monthly rates fluctuate.** The required month-over-month query, [`q6_3.sql`, Query 2a](../queries/unit6/q6_3.sql), counts every trip in the denominator and shows no-shows separately. March reached **18.18% (2 of 11 trips)**; February, April, October, and November each had **0%**. December rebounded to **12.50% (2 of 16)** after the two zero-no-show months, above January's **9.52% (2 of 21)**. All twelve calendar months are present; the `month_check` confirms that `LAG()` does not skip a month. Percentage-point changes convey these jumps more clearly than relative percent changes, which are undefined when the previous rate is zero.

**Quarterly rates declined, although the evidence is limited.** The supporting quarterly query, [`q6_3.sql`, Query 2b](../queries/unit6/q6_3.sql), uses the same rider-no-show definition:

| Quarter | Trip requests | Rider no-shows | Rate | Change from prior quarter |
|---|---:|---:|---:|---:|
| Q1 2023 | 53 | 4 | 7.55% | N/A |
| Q2 2023 | 48 | 3 | 6.25% | -1.30 percentage points |
| Q3 2023 | 51 | 3 | 5.88% | -0.37 percentage points |
| Q4 2023 | 48 | 2 | 4.17% | -1.72 percentage points |
| **Full year** | **200** | **12** | **6.00%** | N/A |

Quarterly rates moved down each time, but monthly samples contain only **11 to 21 trips**. A month with two no-shows can look dramatically worse than a month with none, even if the long-term process has not changed. The supporting [`q6_3.sql`, Query 2c](../queries/unit6/q6_3.sql) checks a **volume-weighted three-month no-show rate** rather than averaging monthly percentages: it peaked at **10.26% in May**, fell to **2.08% in November**, then rose to **4.17% in December**. This supports a cautious reading: observed rates improved over broader windows, but December interrupted that momentum.

**Previously flagged drivers show less improvement.** Assignment 4 identified Drivers **2 and 3** for review and Driver **4** for monitoring, not automatic blame. The new first-half/second-half query ([`q6_3.sql`, Query 2d](../queries/unit6/q6_3.sql)) adds a time comparison to that earlier work:

| Group | Jan to Jun no-shows / trips | Jan to Jun rate | Jul to Dec no-shows / trips | Jul to Dec rate |
|---|---:|---:|---:|---:|
| Drivers 2, 3 and 4 | 3 / 17 | 17.65% | 3 / 18 | 16.67% |
| All other drivers with trips | 4 / 84 | 4.76% | 2 / 81 | 2.47% |

The overall decline is more visible among the other drivers. The groups are small and were identified from the same dataset. Their differences are worth investigating, but they do not explain why the rates changed. The earlier Unit 4 rates still matter: Driver **2 had 3 no-shows in 16 trips (18.75%)**, Driver **3 had 2 in 13 (15.38%)**, and Driver **4 had 1 in just 6 (16.67%)**. Driver 4's rate is especially sensitive to a single event. See the previous [`Unit 4 finding`](unit4-finding.md) and [`Unit 5 finding`](unit5-finding.md) for the driver-level and peer comparisons.

**Supporting query/query result:** The required monthly series in [`q6_3.sql`, Query 2a](../queries/unit6/q6_3.sql) shows 12 consecutive months and an annual total of 12 no-shows / 200 requests (6.00%). Supporting Queries **2b through 2d** provide quarterly rates, a volume-weighted rolling rate, and a flagged-driver half-year comparison. The underlying observations are shown in **Extra 1**.

## 2. What should the team do next quarter?

**Recommendation:**

**1. Review the actual no-show trips, with both driver and rider context.** Use the event list in [`q6_3.sql`, Extra 1](../queries/unit6/q6_3.sql) as the review queue. Start with Driver **2**'s Trips **12, 21, and 26** (January 20, March 10, and December 17) and Driver **3**'s Trips **40 and 31** (May 3 and September 4). Driver **4**'s single no-show, Trip **46** (July 27), belongs on a monitoring list rather than triggering a driver penalty. Verify arrival, pickup location, actual wait, rider/driver contact, cancellation coding, and any support complaint before concluding what occurred. A recorded **rider** no-show does not establish driver fault.

**2. Bring Rider Support into the same review.** Assignment 4 found that **Riders 1 and 21 each had two no-shows with different drivers**. Extra 1 provides the specific records: Rider **1**, Trips **4 and 26**; Rider **21**, Trips **163 and 31**. These account for **four of the twelve incidents**. The repeated rider IDs warrant checking circumstances on both sides; they do not establish intentional rider misconduct. As Unit 4 showed, pickup locations are not necessarily the drivers' home cities, so coordinate with the relevant pickup-area teams.

**3. Keep a stable, transparent monthly report.** Continue to display **trip count, no-show count, no-show rate, previous-month rate, percentage-point change, and `month_check`**. Use quarterly or properly weighted rolling rates alongside the monthly series to avoid overreacting to one or two incidents. A relative percent change after a 0% month is **undefined**, not zero; keep it NULL rather than replacing it with an invented percentage. Review the 12-trip event list behind any large movement before changing policies.

**4. Investigate long inactivity gaps without assuming churn.** [`q6_2.sql`, Query 3](../queries/unit6/q6_2.sql) finds **11 gaps of 60+ full days** across **9 drivers**, including **Driver 11's 88-day gap after no-show Trip 163**. This does not prove the no-show caused the gap. Cross-check driver sign-on/availability and dispatch logs before labeling a gap as actual inactivity or missing data. Separately, verify why **Drivers 14 and 15** were marked active but had no 2023 trip records (the account-level issue established in Unit 5); do not assume they have never driven.

**5. Collect the evidence currently missing from `trips`.** Next-quarter reporting would be more actionable with driver online hours, arrival-at-pickup timestamps, wait durations, contact attempts, and a separate measure of fees actually collected or refunded. These would distinguish a true rider absence from a pickup or logging problem and would also tell us whether a gap reflects unavailability or lack of assigned requests. Measure the outcomes after any operational change before proposing a no-show fee or a bonus-rule adjustment.

**What not to do:** Do **not** reinstate a blanket bonus freeze, treat `NTILE()` bands or fare rankings as a no-show score, or use the **180-trip** and **$4,000 recorded-fare** figures from Task 6.2 as if they were real company goals. Those targets were explicitly **illustrative exercises**. The platform recorded **34 cancelled trips with $0 fares**, but recorded fare amounts do not tell us the actual money collected or what revenue could have been recovered from those cancellations.

**Supporting query/query result:** [`q6_2.sql`, Query 3](../queries/unit6/q6_2.sql) lists the 11 driver gaps; [`q6_3.sql`, Extra 1](../queries/unit6/q6_3.sql) identifies all 12 rider no-show trips for follow-up. The Unit 4 and Unit 5 findings provide the earlier driver/rider comparisons and zero-trip-driver checks.

The quarterly trend is encouraging, but the monthly swings and small sample make it too early to declare success. Next quarter, the team should review the **12 labeled trips** and improve its arrival, wait, and availability data before considering broader penalties or policy changes.
