-- ============================================================================
-- Task 6.3 | Build the reporting patterns
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- Assignment 4 focus: review drivers 2 and 3; monitor driver 4.
-- ============================================================================


-- -----------------------------------------------------------------------------
-- 1 | Part A: Top N per category: What are the three highest-fare
--     trips for each driver, and how do they compare with the highest fare?
--
--    Findings: 39 trips were returned, representing the top three fares
--    for each of the 13 drivers with recorded trips. No ties occurred
--    among the top three fares for any driver.
--    Driver 4 had the highest recorded fare at $70.86, but their
--    second- and third-highest fares were only 32.13% and 20.24%
--    of that amount, respectively.
--    In contrast, Driver 10's top three fares were closely grouped,
--    with the third-highest ($34.41) reaching 97.73% of the maximum.
--
--     Ties at third place are included because RANK() assigns
--     the same rank to trips with equal fares. This may return
--     more than three trips for a driver, but avoids arbitrarily
--     excluding trips with the same fare.
--
--    Requirement: "Return the top three events by metric for each producer.
--    Most leaderboards and recommendation features are built this way."
--
--    ✓ A ranking window function, partitioned by producer.
--    ✓ A CTE or subquery that filters to rank <= 3.
--    ✓ FIRST_VALUE() or LAST_VALUE() used somewhere in your solution.
--    ✓ A comment explaining how ties at third place are handled, and why.
--
--    Notes: RANK() ranks each driver's trips by fare_amount, from highest
--    to lowest. I chose RANK() instead of ROW_NUMBER() because trips
--    with equal fares receive the same rank, including ties at third
--    place. This could return more than three trips per driver, but
--    avoids arbitrarily excluding trips with the same fare.
--
--    FIRST_VALUE() retrieves each driver's highest recorded fare.
--    I included a percentage to show how each trip's fare compares
--    with that maximum. NULLIF() prevents division by zero.
--    The CTE calculates the ranks before the outer query filters
--    for the top three.
--
--    I sorted by fare_rank descending to show third-ranked trips first,
--    since their percentages reveal the largest differences from each
--    driver's maximum. Within each rank, I sorted percentages ascending
--    to highlight the largest differences first. trip_id breaks any
--    remaining ties in the final display order without affecting
--    the rankings.
--
--    These differences don't necessarily indicate unusual pricing or
--    driver performance, since trip distance, surge pricing, and other
--    trip characteristics can affect fares.
--
-- -----------------------------------------------------------------------------

WITH driver_fare_ranks AS (
    SELECT
        driver_id,
        trip_id,
        fare_amount,
        RANK() OVER (
            PARTITION BY driver_id
            ORDER BY fare_amount DESC
        ) AS fare_rank,
        FIRST_VALUE(fare_amount) OVER (
            PARTITION BY driver_id
            ORDER BY fare_amount DESC
        )::NUMERIC(6,2) AS highest_driver_fare
    FROM trips
)
SELECT
    driver_id,
    trip_id,
    fare_rank,
    fare_amount,
    highest_driver_fare,
    ROUND(
        fare_amount / NULLIF(highest_driver_fare, 0) * 100,
        2
    )::NUMERIC(6,2) AS pct_of_highest_fare
FROM driver_fare_ranks
WHERE fare_rank <= 3
ORDER BY fare_rank DESC, pct_of_highest_fare ASC, trip_id;

-- -----------------------------------------------------------------------------
-- 2a | Part B: Period over period: Is the monthly rider no-show rate improving or worsening?
--
--    Findings: The monthly no-show rate fluctuated throughout 2023,
--    with no consistent improvement. March had the highest rate at
--    18.18% (2 of 11 trips). February, April, October, and November
--    had no recorded no-shows.
--    Despite reaching 0% in October and November, the rate increased
--    to 12.50% in December (2 of 16 trips), compared with 9.52%
--    in January. All 12 months were present, with no missing months.
--
--    Requirement: "Is the platform getting better or worse each month? This is the founder’s
--    real question. Group your events by calendar month, then compare each month with the
--    month before."
--
--    ✓ Group events into months (for example, with DATE_TRUNC('month', ...)).
--    ✓ LAG() over the monthly series.
--    ✓ A percent-change column that avoids division by zero (for example, with
--    NULLIF(..., 0)).
--    ✓ A check for missing months. LAG counts rows, so a missing month makes it compare
--    the wrong months.
--
--    Notes: DATE_TRUNC() groups trips by calendar month. COUNT(*) FILTER
--    counts rider no-shows while keeping all trips in the denominator.
--    I used the no-show rate instead of the count alone because monthly
--    trip volumes differ.
--    LAG() retrieves the previous month's rate for comparison.
--    change_pct_points measures the difference between rates, while
--    pct_change measures the relative percentage change.
--    NULLIF() prevents division by zero. pct_change returns NULL
--    for the first month or when the previous month's rate is 0%.
--    The month_check column verifies that LAG() compares consecutive
--    calendar months rather than skipping missing months.
--    Monthly trip counts are relatively small, so even one additional
--    no-show can noticeably affect the rate.
--
-- -----------------------------------------------------------------------------
WITH monthly_totals AS (
    SELECT
        DATE_TRUNC('month', requested_at)::date AS month_start,
        COUNT(*) AS monthly_trips,
        COUNT(*) FILTER (
            WHERE cancellation_reason = 'Rider no show'
        ) AS monthly_no_shows,
        100.0 * COUNT(*) FILTER (
            WHERE cancellation_reason = 'Rider no show'
        ) / COUNT(*) AS no_show_rate
    FROM trips
    GROUP BY DATE_TRUNC('month', requested_at)::date
)
SELECT
    month_start,
    monthly_trips,
    monthly_no_shows,
    ROUND(no_show_rate, 2)::NUMERIC(6,2) AS no_show_rate,
    ROUND(
        LAG(no_show_rate) OVER (ORDER BY month_start),
        2
    )::NUMERIC(6,2) AS prior_month_rate,
    ROUND(
        no_show_rate - LAG(no_show_rate) OVER (ORDER BY month_start),
        2
    )::NUMERIC(6,2) AS change_pct_points,
    ROUND(
        100.0 * (no_show_rate - LAG(no_show_rate) OVER (ORDER BY month_start))
        / NULLIF(LAG(no_show_rate) OVER (ORDER BY month_start), 0),
        2
    )::NUMERIC(6,2) AS pct_change,
    CASE
        WHEN LAG(month_start) OVER (ORDER BY month_start) IS NULL
            THEN 'First month'
        WHEN month_start = (
            LAG(month_start) OVER (ORDER BY month_start)
            + INTERVAL '1 month'
        )::date
            THEN 'Consecutive'
        ELSE 'Missing month(s)'
    END AS month_check
FROM monthly_totals
ORDER BY month_start;
