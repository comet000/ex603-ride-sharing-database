-- ============================================================================
-- Task 6.2 | Compare each row to its neighbors
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- Assignment 4 focus: review drivers 2 and 3; monitor driver 4.
--
-- Important : All trip statuses and $0 fares are included to measure recorded
-- fare per trip request, rather than only fares from completed rides.
-- Cancelled trips that generate no fare are relevant to the platform's
-- financial performance, especially given our focus on rider no-shows.
-- Excluding them would hide the financial impact of these cancellations
-- and potentially make performance appear better than it is.
-- This also keeps the analysis consistent with Task 6.1.
-- However, fare changes may reflect cancellations or differences in
-- trip characteristics rather than changes in pricing or driver performance.
-- ============================================================================


-- -----------------------------------------------------------------------------
-- 1 | Part A: Row to row: For one driver, how did fare amount change from trip to trip?
--
--    Findings: 16 trips for Driver 2, with 15 consecutive fare comparisons.
--    Fares range from $0 to $47.81.
--    Of the 15 changes, 7 are increases, 7 are decreases, and 1 is unchanged.
--    The largest increase is +$27.98 (Trip 18), from $19.83 to $47.81.
--    The largest decrease is -$32.59 (Trip 23), from $47.81 to $15.22.
--    The final recorded trip has a $0 fare, down $20.29 from the previous trip.
--    Five of Driver 2's 16 trips have $0 fares, contributing
--    to several large fluctuations between consecutive trips.
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
--    Notes: LAG() and LEAD() compare each trip's fare with the previous
--    and next trips for the same driver, ordered by requested_at.
--    trip_id breaks ties when requests have identical timestamps,
--    ensuring a consistent sequence.
--    Positive changes indicate increases; negative changes indicate decreases.
--    The first trip has no previous fare, and the last has no next fare,
--    so those comparisons return NULL.
--    All trip statuses are included. $0 fares can create large changes,
--    so these fluctuations do not necessarily indicate changes in driver
--    performance.
--
-- -----------------------------------------------------------------------------
SELECT
    driver_id,
    trip_id,
    TO_CHAR(requested_at, 'YYYY-MM-DD HH24:MI') AS requested_at,
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
        ORDER BY requested_at
    ) AS fare_change_from_prev,
    LEAD(fare_amount) OVER (
        PARTITION BY driver_id
        ORDER BY requested_at, trip_id
    ) - fare_amount AS fare_change_to_next
FROM trips
WHERE driver_id = 2
ORDER BY driver_id, requested_at, trip_id;

-- -----------------------------------------------------------------------------
-- 2a | Part B: Cumulative: How has trip volume grown toward our annual target?
--
--    Findings: The platform recorded 200 trip requests in 2023.
--    January and February had the most trips (21 each), while March
--    and April had the fewest (11 each). Against an illustrative
--    annual target of 180 trips, the platform reached 111.11%,
--    exceeding the target by 20 trips.
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
--    Notes: I grouped trips by requested_at to include all requests,
--    including cancellations and $0 fares. The running SUM() shows
--    how trip counts accumulated throughout the year without losing
--    the monthly breakdown. I chose 180 trips as a hypothetical annual
--    target because it represents 15 requests per month. It's not an
--    actual company target, and higher trip volume doesn't necessarily
--    mean better performance if cancellations are also increasing.
--
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
-- 2b | Part B: Cumulative: How have recorded fares accumulated toward our annual target?
--
--
--    Findings: Total recorded fares reached $3,628.19 by December 2023.
--    February had the highest monthly total ($453.44), while March
--    had the lowest ($135.98). Against an illustrative annual target
--    of $4,000, the platform reached 90.7%, falling short by $371.81.
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
--    Notes: SUM(fare_amount) calculates recorded fares for each month.
--    We include $0 fares because we're analyzing all trip requests,
--    although those requests add nothing to the fare total.
--    The running SUM() shows how the monthly amounts accumulated.
--    Since the assignment asks us to choose a target, I used $4,000
--    as a simple hypothetical annual benchmark, not an actual company
--    goal. The extra CTE lets me use the running total to calculate
--    progress toward that benchmark without repeating the window
--    calculation. Recorded fares aren't necessarily revenue collected.
--
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
    4000.00 AS annual_fare_target,
    ROUND(
        cumulative_recorded_fares / 4000.00 * 100,
        2
    )::NUMERIC(6,2) AS pct_of_target
FROM monthly_progress
ORDER BY month_start;

-- -----------------------------------------------------------------------------
-- 2c | Part B: Smoothed: How has the three-month moving average
--      of monthly trip counts changed over time?
--
--    Findings: Among full three-month windows, the moving average
--    reached its lowest point in May (13.00 trips per month) and
--    its highest in August (18.33). By December, it was 16.00.
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
--    Notes: I used a three-month moving average to smooth out
--    fluctuations in monthly trip counts without losing sight of
--    recent changes. A shorter window would react more strongly
--    to individual months, while a longer one could hide changes.
--    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW includes the current
--    month and the previous two monthly rows. January and February
--    use fewer months because earlier data isn't available.
--
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
-- 2d | Part B: Smoothed: How has the three-month moving average
--      of monthly recorded fares changed over time?
--
--    Findings: Among full three-month windows, the moving average
--    of monthly recorded fares was lowest in May ($234.61) and
--    highest in October ($357.63). It ended December at $285.77.
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
--    Notes: I used a three-month moving average to smooth out
--    fluctuations in recorded fares while still capturing recent
--    changes. A one-month window wouldn't smooth anything, while
--    a six-month window would make it harder to spot shorter-term
--    trends in a dataset covering only 12 months.
--    I used the same window as 2c so we can compare fare trends
--    with trip volume. January and February use shorter
--    windows because earlier months aren't available.
--
--    ROWS counts individual rows, while RANGE groups rows that share
--    the same ORDER BY value. When there are ties, ROWS adds them one
--    at a time, while RANGE includes them together.
--    Since we have only one row per month, this doesn't affect our results.
--    All 12 months have trip activity. If some months were missing,
--    our three-row moving average could cover more than three
--    consecutive calendar months.
--
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
-- 3 | Part C: Where the series stops: When did drivers have significant
--     gaps in recorded trip activity, and what happened before those gaps?
--
--    Findings: 11 gaps of at least 60 days were found across 9 of the
--    13 drivers with recorded trips. Drivers 1 and 3 each had two
--    long gaps, while the other seven drivers had one each.
--    Driver 9 had the longest gap at 112 days.
--    Of the 11 gaps, 8 followed completed trips and 3 followed
--    cancellations. None followed disputed trips.
--    Driver 11 had an 88-day gap following a rider no-show.
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
--    Notes: I chose a 60-day threshold to focus on gaps lasting roughly
--    two months or longer, rather than shorter interruptions.
--    This also lets us identify drivers with repeated long gaps.
--    LAG() finds each driver's previous trip, including its status
--    and cancellation reason. I kept the previous trip ID so any
--    concerning cases can be investigated further.
--    Ordering by requested_at and trip_id ensures a consistent sequence
--    if two requests have the same timestamp.
--    The gap calculation excludes the dates of the trips on either side.
--    I used a CTE to calculate the previous trip's information before
--    filtering for gaps in the outer query.
--    A gap doesn't necessarily mean the driver stopped working. They
--    may have received no requests, been inactive, or had activity
--    missing from the data. With only 200 trips across 13 active
--    drivers over a year, long gaps may also reflect sparse data.
--    A cancellation immediately before a gap doesn't establish
--    that it caused the gap.
--
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
ORDER BY missing_days DESC, driver_id;
