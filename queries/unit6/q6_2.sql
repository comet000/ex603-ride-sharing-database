-- ============================================================================
-- Task 6.2 | Compare each row to its neighbors
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- Assignment 4 focus: review drivers 2 and 3; monitor driver 4.
--
-- Important: All trip statuses and $0 fares are included, as in Task 6.1.
-- This measures recorded fare per trip request, not only completed rides.
-- Cancelled trips matter to the platform's financial performance, especially
-- when examining rider no-shows. Excluding them would hide part of the impact
-- and make fares per request look better than they are. Fare changes may also
-- reflect distance or surge pricing, not changes in driver performance.
-- Recorded fares are not necessarily money collected. Timestamps and numbers
-- retain their native SQL types; calculated decimals use two decimal places.
-- ============================================================================


-- -----------------------------------------------------------------------------
-- 1 | Part A: For Driver 2, how does fare change from one trip to the next?
--
--    Findings: Driver 2 has 16 trips and 15 trip-to-trip changes:
--    7 increases, 7 decreases, and 1 unchanged ($0 to $0).
--    Fares range from $0 to $47.81. The largest increase is +$27.98 on
--    Trip 18 (from $19.83 to $47.81, with 2.00x surge); the largest
--    decrease is -$32.59 on Trip 23 (from $47.81 to $15.22).
--    The last trip (26) is a $0 rider no-show, down $20.29 from the
--    previous trip. Four trips have $0 fares: 12, 14, 21, and 26.
--    Three were rider no-shows; Trip 14 was 'Driver unavailable'.
--
--    Requirement: "Is a producer’s metric going up or down over time, not just high or low
--    overall? For each event, show the metric from the previous event and the next event, in
--    time order."
--
--    ✓ LAG() and LEAD(), partitioned by producer and ordered by timestamp.
--    ✓ A delta column: the current metric minus the previous metric.
--    ✓ In the final output, filter to one producer of your choice so the trend is easy to
--    read.
--
--    Notes / tie-breaker decision: I use ORDER BY requested_at, trip_id
--    in ALL four LAG()/LEAD() windows. If two requests share a timestamp,
--    trip_id supplies a stable sequence, so fare_change_from_prev agrees
--    with the displayed prev_fare_amount (and likewise for next fare).
--    Without the same tie-breaker, two calculations could choose different
--    neighboring rows. trip_id does not prove which simultaneous trip
--    actually happened first; it is only a reproducible ordering rule.
--    No Driver 2 timestamps tie in this dataset, so results do not change.
--    Filtering to Driver 2 here is safe because the windows are already
--    PARTITIONed by driver. The first/last neighboring fares are NULL.
--    trip_status, cancellation_reason, and surge_multiplier help explain
--    why a fare changed without treating it as a performance verdict.
-- -----------------------------------------------------------------------------
SELECT
    driver_id,
    trip_id,
    requested_at,
    trip_status,
    cancellation_reason,
    surge_multiplier,
    fare_amount,
    LAG(fare_amount) OVER (
        PARTITION BY driver_id
        ORDER BY requested_at, trip_id
    ) AS prev_fare_amount,
    LEAD(fare_amount) OVER (
        PARTITION BY driver_id
        ORDER BY requested_at, trip_id
    ) AS next_fare_amount,
    fare_amount - LAG(fare_amount) OVER (
        PARTITION BY driver_id
        ORDER BY requested_at, trip_id
    ) AS fare_change_from_prev,
    LEAD(fare_amount) OVER (
        PARTITION BY driver_id
        ORDER BY requested_at, trip_id
    ) - fare_amount AS fare_change_to_next
FROM trips
WHERE driver_id = 2
ORDER BY requested_at, trip_id;


-- -----------------------------------------------------------------------------
-- 2a | Part B: How have monthly trip requests accumulated toward a target?
--
--    Findings: The platform recorded 200 requests in 2023. January and
--    February had 21 each; March and April had 11 each. Against an
--    illustrative annual target of 180 requests (15/month), the running
--    total reached 184 in November (102.22%), then 200 (111.11%) in
--    December, 20 trips above target. This is NOT a company target.
--
--    Requirement: "How is the platform doing over time, both in total and on a recent
--    average? Leadership wants to see where things stand now and how they got there."
--
--    ✓ SUM(...) OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) for
--    a running total.
--    ✓ AVG(...) OVER (... ROWS BETWEEN n PRECEDING AND CURRENT ROW) for a moving average.
--    Note: ROWS counts rows, not days. If some days have no events, a 7-row window covers
--    more than 7 days.
--    ✓ Choose a target (for example, a total for the quarter), state it, and show how
--    close the running total gets to it.
--    ✓ One or two sentences on how ROWS differs from RANGE when two rows have the same
--    ORDER BY value.
--
--    Notes: One row per month allows the running total to show the pace,
--    not only the year-end count. All requests count, including cancelled
--    ones. More requests do not necessarily mean more completed rides.
--    The second CTE lets pct_of_target reuse the running total without
--    repeating the window expression.
-- -----------------------------------------------------------------------------
WITH monthly_trip_totals AS (
    SELECT
        DATE_TRUNC('month', requested_at)::date AS month_start,
        COUNT(*) AS monthly_trips
    FROM trips
    GROUP BY DATE_TRUNC('month', requested_at)::date
),
trip_running_totals AS (
    SELECT
        month_start,
        monthly_trips,
        SUM(monthly_trips) OVER (
            ORDER BY month_start
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_trips
    FROM monthly_trip_totals
)
SELECT
    month_start,
    monthly_trips,
    cumulative_trips,
    180 AS illustrative_annual_target,
    ROUND(
        cumulative_trips / 180.0 * 100,
        2
    )::NUMERIC(6,2) AS pct_of_target
FROM trip_running_totals
ORDER BY month_start;


-- -----------------------------------------------------------------------------
-- 2b | Part B: How have recorded fares accumulated toward a target?
--
--    Findings: 2023 recorded fares total $3,628.19. February was highest
--    ($453.44), March lowest ($135.98). Against an illustrative $4,000
--    annual benchmark (NOT a real company target), the running total
--    finished at 90.70%, or $371.81 short.
--
--    Requirement: "How is the platform doing over time, both in total and on a recent
--    average? Leadership wants to see where things stand now and how they got there."
--
--    ✓ SUM(...) OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) for
--    a running total.
--    ✓ AVG(...) OVER (... ROWS BETWEEN n PRECEDING AND CURRENT ROW) for a moving average.
--    Note: ROWS counts rows, not days. If some days have no events, a 7-row window covers
--    more than 7 days.
--    ✓ Choose a target (for example, a total for the quarter), state it, and show how
--    close the running total gets to it.
--    ✓ One or two sentences on how ROWS differs from RANGE when two rows have the same
--    ORDER BY value.
--
--    Notes: SUM(fare_amount) includes $0 cancellations without adding
--    anything to the total. A recorded fare is not necessarily revenue
--    collected. The second CTE avoids repeating the running SUM().
-- -----------------------------------------------------------------------------
WITH monthly_fare_totals AS (
    SELECT
        DATE_TRUNC('month', requested_at)::date AS month_start,
        SUM(fare_amount) AS monthly_fares
    FROM trips
    GROUP BY DATE_TRUNC('month', requested_at)::date
),
monthly_progress AS (
    SELECT
        month_start,
        monthly_fares,
        SUM(monthly_fares) OVER (
            ORDER BY month_start
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_recorded_fares
    FROM monthly_fare_totals
)
SELECT
    month_start,
    monthly_fares,
    cumulative_recorded_fares,
    4000.00 AS illustrative_annual_fare_target,
    ROUND(
        cumulative_recorded_fares / 4000.00 * 100,
        2
    )::NUMERIC(6,2) AS pct_of_target
FROM monthly_progress
ORDER BY month_start;


-- -----------------------------------------------------------------------------
-- 2c | Part B: What is the trailing three-month average of trip requests?
--
--    Findings: Among FULL three-month windows, the low was 13.00 trips
--    per month in May, the high was 18.33 in August, and December's
--    average was 16.00.
--
--    Requirement: "How is the platform doing over time, both in total and on a recent
--    average? Leadership wants to see where things stand now and how they got there."
--
--    ✓ SUM(...) OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) for
--    a running total.
--    ✓ AVG(...) OVER (... ROWS BETWEEN n PRECEDING AND CURRENT ROW) for a moving average.
--    Note: ROWS counts rows, not days. If some days have no events, a 7-row window covers
--    more than 7 days.
--    ✓ Choose a target (for example, a total for the quarter), state it, and show how
--    close the running total gets to it.
--    ✓ One or two sentences on how ROWS differs from RANGE when two rows have the same
--    ORDER BY value.
--
--    Notes: Three months smooths monthly volatility while preserving
--    recent direction. January uses one month and February uses two;
--    only March onward has a full three-month window. ROWS counts rows,
--    not calendar months; the month_check in q6_3.sql confirms that
--    all twelve calendar months exist in this dataset.
-- -----------------------------------------------------------------------------
WITH monthly_trip_totals AS (
    SELECT
        DATE_TRUNC('month', requested_at)::date AS month_start,
        COUNT(*) AS monthly_trips
    FROM trips
    GROUP BY DATE_TRUNC('month', requested_at)::date
)
SELECT
    month_start,
    monthly_trips,
    ROUND(
        AVG(monthly_trips) OVER (
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    )::NUMERIC(6,2) AS moving_avg_trips_3mo
FROM monthly_trip_totals
ORDER BY month_start;


-- -----------------------------------------------------------------------------
-- 2d | Part B: What is the trailing three-month average of recorded fares?
--
--    Findings: Among FULL three-month windows, May was lowest at
--    $234.61/month and October was highest at $357.63/month.
--    The December moving average was $285.77/month.
--
--    Requirement: "How is the platform doing over time, both in total and on a recent
--    average? Leadership wants to see where things stand now and how they got there."
--
--    ✓ SUM(...) OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) for
--    a running total.
--    ✓ AVG(...) OVER (... ROWS BETWEEN n PRECEDING AND CURRENT ROW) for a moving average.
--    Note: ROWS counts rows, not days. If some days have no events, a 7-row window covers
--    more than 7 days.
--    ✓ Choose a target (for example, a total for the quarter), state it, and show how
--    close the running total gets to it.
--    ✓ One or two sentences on how ROWS differs from RANGE when two rows have the same
--    ORDER BY value.
--
--    Notes: Same frame as 2c, so we can compare fare and trip trends.
--    January/February have shorter windows. ROWS counts physical rows;
--    with equal ORDER BY values it can add tied rows one at a time.
--    RANGE uses ordering values and includes all peers with equal values
--    together. For equivalent calendar boundaries in a complete one-row-
--    per-month series, there are no monthly peers to split; different
--    ROWS/RANGE frame boundaries can still give different results.
-- -----------------------------------------------------------------------------
WITH monthly_fare_totals AS (
    SELECT
        DATE_TRUNC('month', requested_at)::date AS month_start,
        SUM(fare_amount) AS monthly_fares
    FROM trips
    GROUP BY DATE_TRUNC('month', requested_at)::date
)
SELECT
    month_start,
    monthly_fares,
    ROUND(
        AVG(monthly_fares) OVER (
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    )::NUMERIC(6,2) AS moving_avg_fares_3mo
FROM monthly_fare_totals
ORDER BY month_start;


-- -----------------------------------------------------------------------------
-- 3 | Part C: Where did drivers have gaps of 60+ days with no recorded trip?
--
--    Findings: 11 gaps of at least 60 days across 9 of 13 drivers with
--    recorded trips. Drivers 1 and 3 have two gaps each. Driver 9's
--    112-day gap is longest. Eight gaps follow completed trips; three
--    follow cancellations; none follow disputes. Driver 11's 88-day gap
--    A cancellation just before a gap does not prove it caused that gap.
--
--    Requirement: "One producer stops for a while and then starts again. Find that gap. Then
--    think about what you cannot tell yet: did the producer leave, or did your data lose
--    them?"
--
--    ✓ LAG() or LEAD() comparing adjacent rows.
--    ✓ A CTE or subquery that computes the gap, and a WHERE in the outer query that keeps
--    only the gaps. (You cannot filter a window function result with WHERE or HAVING in
--    the same query, because the window function runs after them.)
--
--    Notes / tie-breaker decision: All LAG() calls use requested_at,
--    trip_id so previous-trip details come from the same preceding row.
--    Without trip_id, equal timestamps could yield inconsistent previous
--    trips or statuses. This ensures reproducible order, not real-world
--    chronology for simultaneous requests.
--    I chose a 60-day threshold to focus on gaps lasting about two months
--    or longer and to spot drivers with repeated gaps. The calculation counts
--    whole days strictly BETWEEN trips, excluding the trips' own dates.
--    I kept the preceding trip ID for a follow-up review. With only 200 trip
--    records, a gap could mean a driver was inactive, got no requests, or has
--    missing records. We would need availability and logging data to know.
--    A cancellation just before a gap does not prove it caused that gap.
--    COALESCE shows N/A rather than NULL for missing cancellation reasons;
--    it only changes a text label, not any timestamp or numeric value.
-- -----------------------------------------------------------------------------
WITH trip_sequence AS (
    SELECT
        driver_id,
        requested_at::date AS trip_date,
        LAG(trip_id) OVER (
            PARTITION BY driver_id
            ORDER BY requested_at, trip_id
        ) AS last_trip_before_gap,
        LAG(requested_at::date) OVER (
            PARTITION BY driver_id
            ORDER BY requested_at, trip_id
        ) AS prev_date,
        LAG(trip_status) OVER (
            PARTITION BY driver_id
            ORDER BY requested_at, trip_id
        ) AS last_trip_status,
        LAG(cancellation_reason) OVER (
            PARTITION BY driver_id
            ORDER BY requested_at, trip_id
        ) AS last_cancellation_reason
    FROM trips
)
SELECT
    driver_id,
    last_trip_before_gap,
    prev_date + 1 AS gap_start,
    trip_date - 1 AS gap_end,
    trip_date - prev_date - 1 AS missing_days,
    last_trip_status,
    COALESCE(last_cancellation_reason, 'N/A') AS last_cancellation_reason
FROM trip_sequence
WHERE trip_date - prev_date - 1 >= 60
ORDER BY missing_days DESC, driver_id, last_trip_before_gap;
