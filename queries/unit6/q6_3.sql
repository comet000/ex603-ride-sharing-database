-- ============================================================================
-- Task 6.3 | Build the reporting patterns
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- Assignment 4 focus: review drivers 2 and 3; monitor driver 4.
--
-- Queries 1 and 2a satisfy REQUIRED Parts A and B. Queries 2b-2d and
-- Extra 1 are supporting evidence for the Task 6.4 memo, not extra
-- assignment requirements. Dates and numeric values retain native types.
-- ============================================================================


-- -----------------------------------------------------------------------------
-- 1 | Part A: What are each driver's three highest-fare trips, relative
--     to that driver's highest recorded fare?
--
--    Findings: 39 trips: three for each of 13 drivers with recorded
--    trips. There are no ties among any driver's top three fares.
--    Driver 4's highest is $70.86 (Trip 43), while their second and
--    third fares ($22.77 and $14.34) are 32.13% and 20.24% of that
--    maximum. Driver 10's third-highest fare ($34.41) is 97.73% of
--    their highest ($35.21).
--
--    Requirement: "Return the top three events by metric for each producer.
--    Most leaderboards and recommendation features are built this way."
--
--    ✓ A ranking window function, partitioned by producer.
--    ✓ A CTE or subquery that filters to rank <= 3.
--    ✓ FIRST_VALUE() or LAST_VALUE() used somewhere in your solution.
--    If using LAST_VALUE(), add ROWS BETWEEN UNBOUNDED PRECEDING AND
--    UNBOUNDED FOLLOWING; otherwise its default frame can give the wrong value.
--    ✓ A comment explaining how ties at third place are handled, and why.
--
--    Notes / tie policy: RANK() sorts fare_amount DESC within each driver.
--    Equal fares retain equal ranks, including at third place; the query
--    could return more than three rows for one driver rather than drop a
--    tied trip. I deliberately do NOT add trip_id to the RANK() ordering:
--    doing so would turn equal fares into different rank values.
--    FIRST_VALUE() retrieves the top fare; with highest first it is correct
--    under the default frame (the LAST_VALUE() default-frame trap does not
--    apply here). The CTE ranks before the outer WHERE filters.
--    NULLIF() protects the percentage calculation if a top fare is $0.
--    For analysis I kept our original display sort: third-ranked fares
--    first, then the lowest percentage of the highest fare. trip_id is a
--    final DISPLAY tie-breaker only; without it, rows sharing both sort
--    values could appear in either order. It does not affect fare ranks.
--    Fare differences do not prove pricing or driver-performance issues;
--    distance and surge matter too.
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
-- 2a | Part B: Is the monthly rider no-show rate improving or worsening?
--
--    Findings: No sustained month-to-month improvement. March has the
--    highest monthly rate: 2 of 11 trips, 18.18%. February, April,
--    October, and November have no rider no-shows. The rate rose from
--    0.00% in November to 12.50% in December (2 of 16), versus 9.52%
--    in January (2 of 21). All 12 calendar months are present.
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
--    Notes: COUNT(*) FILTER counts rider no-shows; COUNT(*) keeps all
--    trip requests in the denominator. The rate is more comparable than
--    the raw count because monthly volumes differ. LAG() retrieves the
--    preceding monthly row. change_pct_points is the primary operational
--    difference between the two rates; pct_change is the relative change
--    required by the assignment. NULLIF() returns NULL for pct_change
--    when the prior rate is 0% (March, May, November, December); the
--    first month also has no prior observation. NULL is not 0% change.
--    Point changes are calculated BEFORE rounding displayed rates: August
--    shows -0.33 points, even though 5.56 - 5.88 displays as -0.32.
--    month_check flags a skipped month: LAG() alone follows rows, not
--    calendar periods. If any month is missing, review that comparison
--    rather than treating it as the immediately preceding calendar month.
--    Monthly samples are only 11-21 trips, so rates are volatile.
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


-- -----------------------------------------------------------------------------
-- 2b | Supporting Task 6.4: Has the no-show rate changed by quarter?
--
--    Findings: Q1 4/53 = 7.55%, Q2 3/48 = 6.25%, Q3 3/51 = 5.88%,
--    Q4 2/48 = 4.17%. The rates decline each quarter, but only 12
--    no-shows were recorded all year, so this is not proof of a lasting
--    improvement. All four quarters are consecutive.
--
--    Notes: Same monthly pattern as 2a at quarterly grain; LAG() gives
--    the prior quarter and quarter_check flags gaps. Point changes are
--    calculated from unrounded rates, then rounded to two decimals.
-- -----------------------------------------------------------------------------
WITH quarterly_totals AS (
    SELECT
        DATE_TRUNC('quarter', requested_at)::date AS quarter_start,
        COUNT(*) AS quarterly_trips,
        COUNT(*) FILTER (
            WHERE cancellation_reason = 'Rider no show'
        ) AS quarterly_no_shows,
        100.0 * COUNT(*) FILTER (
            WHERE cancellation_reason = 'Rider no show'
        ) / COUNT(*) AS no_show_rate
    FROM trips
    GROUP BY DATE_TRUNC('quarter', requested_at)::date
)
SELECT
    quarter_start,
    quarterly_trips,
    quarterly_no_shows,
    ROUND(no_show_rate, 2)::NUMERIC(6,2) AS no_show_rate,
    ROUND(
        LAG(no_show_rate) OVER (ORDER BY quarter_start),
        2
    )::NUMERIC(6,2) AS prior_quarter_rate,
    ROUND(
        no_show_rate - LAG(no_show_rate) OVER (ORDER BY quarter_start),
        2
    )::NUMERIC(6,2) AS change_pct_points,
    CASE
        WHEN LAG(quarter_start) OVER (ORDER BY quarter_start) IS NULL
            THEN 'First quarter'
        WHEN quarter_start = (
            LAG(quarter_start) OVER (ORDER BY quarter_start)
            + INTERVAL '3 months'
        )::date
            THEN 'Consecutive'
        ELSE 'Missing quarter(s)'
    END AS quarter_check
FROM quarterly_totals
ORDER BY quarter_start;


-- -----------------------------------------------------------------------------
-- 2c | Supporting Task 6.4: What is the trailing three-month no-show rate?
--
--    Findings: Among full three-month windows, the rate peaked at
--    10.26% in May (Mar-May), fell to 2.08% in November (Sep-Nov),
--    and rose to 4.17% in December (Oct-Dec).
--
--    Notes: Add no-shows and trips over the same window, then divide.
--    This is a volume-weighted rate, NOT an unweighted average of three
--    monthly percentages. The first two rows use partial windows.
--    ROWS represents three calendar months here because 2a verified
--    there are no missing months.
-- -----------------------------------------------------------------------------
WITH monthly_totals AS (
    SELECT
        DATE_TRUNC('month', requested_at)::date AS month_start,
        COUNT(*) AS monthly_trips,
        COUNT(*) FILTER (
            WHERE cancellation_reason = 'Rider no show'
        ) AS monthly_no_shows
    FROM trips
    GROUP BY DATE_TRUNC('month', requested_at)::date
)
SELECT
    month_start,
    monthly_trips,
    monthly_no_shows,
    ROUND(
        100.0 * monthly_no_shows / monthly_trips,
        2
    )::NUMERIC(6,2) AS monthly_no_show_rate,
    COUNT(*) OVER (
        ORDER BY month_start
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS months_in_window,
    ROUND(
        100.0 * SUM(monthly_no_shows) OVER (
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) / SUM(monthly_trips) OVER (
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    )::NUMERIC(6,2) AS rolling_3mo_no_show_rate
FROM monthly_totals
ORDER BY month_start;


-- -----------------------------------------------------------------------------
-- 2d | Supporting Task 6.4: Did no-show rates change for the drivers
--      flagged in Assignment 4 versus everyone else, first half to second?
--
--    Findings: Drivers 2, 3, and 4 together: 3/17 = 17.65% in H1 and
--    3/18 = 16.67% in H2. Other drivers: 4/84 = 4.76% in H1 and
--    2/81 = 2.47% in H2. The aggregate decline is more visible outside
--    the flagged group. These small, post-hoc groups are descriptive,
--    NOT evidence that any driver caused rider no-shows.
--
--    Notes: This adds a TIME dimension to Unit 4's driver comparisons.
--    It does not replace the original distinction: review Drivers 2 and
--    3, monitor Driver 4 because six trips are too few for a pattern.
-- -----------------------------------------------------------------------------
WITH labeled_trips AS (
    SELECT
        cancellation_reason,
        CASE
            WHEN driver_id IN (2, 3, 4) THEN 'Drivers 2, 3, 4'
            ELSE 'Other drivers'
        END AS driver_group,
        CASE
            WHEN EXTRACT(MONTH FROM requested_at) <= 6 THEN 'H1 (Jan-Jun)'
            ELSE 'H2 (Jul-Dec)'
        END AS half_year
    FROM trips
)
SELECT
    driver_group,
    half_year,
    COUNT(*) AS trips,
    COUNT(*) FILTER (
        WHERE cancellation_reason = 'Rider no show'
    ) AS no_shows,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE cancellation_reason = 'Rider no show')
        / COUNT(*),
        2
    )::NUMERIC(6,2) AS no_show_rate
FROM labeled_trips
GROUP BY driver_group, half_year
ORDER BY driver_group, half_year;


-- -----------------------------------------------------------------------------
-- Extra 1 | Supporting Task 6.4: Which rider no-show trips should
--     Driver Operations and Rider Support review?
--
--    Findings: 12 trips across 9 drivers. Driver 2 has three (Trips 12,
--    21, 26); Driver 3 has two (40, 31); Driver 4 has one (46).
--    Rider 1 has two (4 and 26), and Rider 21 has two (163 and 31),
--    each involving different drivers. These riders were identified in
--    Unit 4; this query adds the dates, IDs, and pickup cities for review.
--
--    Notes: This is a deliberately simple event list, not another rate
--    calculation. It supports the action plan in the closing memo. The
--    final trip_id ORDER BY breaks ties in displayed timestamps, so the
--    review queue is reproducible without changing who qualified.
-- -----------------------------------------------------------------------------
SELECT
    trip_id,
    driver_id,
    rider_id,
    requested_at,
    pickup_city,
    trip_status,
    cancellation_reason
FROM trips
WHERE cancellation_reason = 'Rider no show'
ORDER BY requested_at, trip_id;
