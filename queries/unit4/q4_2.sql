-- ============================================================================
-- Task 4.2 | Build the breakdown leadership asked for
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (as in Unit 3).
-- =============================================================================

-- Part A: How many total trips and total no-shows are associated with each driver?

--    Findings: 13 drivers with trips; their counts sum to 200 trips and 12
--    no-shows. Drivers 2, 4 and 3 have the highest observed rates:
--    3/16 = 18.75%, 1/6 = 16.67%, and 2/13 = 15.38%.
--    Drivers 1, 4 and 13 are flagged 'No - small sample' (< 13 trips).

--    Requirement: For each producer (driver), compute the total number of events (trips)
--    and the total number of events (trips) classified as failures (no-shows),
--    in a single pass over the event (trips) table, without a WHERE clause filtering the whole query.
--    CASE used inside an aggregate
--    Both totals appearing as separate columns in one result set.
--    Notes: Unlike 4.1 Q3 (which uses HAVING and shows only 10 drivers), this shows all 13 drivers
--    and flags small samples in enough_volume instead of dropping them.
--    Drivers 14 and 15, who both have 0 trips, are excluded from the analysis.

WITH driver_summary AS (
    SELECT
        t.driver_id,
        d.avg_rating AS driver_rating,
        COUNT(*) AS total_trips,
        COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END)
            AS rider_no_shows
    FROM trips t
    JOIN drivers d ON t.driver_id = d.driver_id
    GROUP BY t.driver_id, d.avg_rating
),
volume_threshold AS (
    SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_trips)
        AS min_trips
    FROM driver_summary
)
SELECT
    s.driver_id,
    s.total_trips,
    s.rider_no_shows,
    (100.0 * s.rider_no_shows / s.total_trips)::numeric(10,2) AS failure_rate,
    s.driver_rating,
    CASE
        WHEN s.total_trips >= v.min_trips THEN 'Yes'
        ELSE 'No - small sample'
    END AS enough_volume
FROM driver_summary s
CROSS JOIN volume_threshold v
ORDER BY failure_rate DESC, s.driver_id ASC;

-- Part B1: What are the regional subtotals by geographic pickup region? What is the platform-wide grand total or average?
--    Region = North/Central/South by pickup city.
--    Rows where row_type = 'Regional subtotal / avg' are the subtotals (one per region).
--    The single row with row_type = 'Grand total or average' is the platform-wide total.

--    Findings: Three 'Regional subtotal' rows: North 6/77 = 7.79%,
--    Central 5/83 = 6.02%, South 1/40 = 2.50%.
--    One 'Grand total' row: 12/200 = 6.00%, sum of fares = $3628.19.

--    Requirement: subtotals per region and a platform grand total.
--    Do not include individual detail rows.
--    Note identifying which rows are the subtotals and which is the grand total.
--    Notes: avg_driver_rating weights each driver's rating by trip count; it is
--    NOT the average of distinct drivers' ratings.
--    Zero fare trips are omitted only from avg_positive_fare.

WITH trip_regions AS (
    SELECT
        t.trip_id,
        t.fare_amount,
        t.cancellation_reason,
        t.pickup_city,
        d.avg_rating,
        CASE
            WHEN t.pickup_city IN ('Hanoi', 'Haiphong') THEN 'North'
            WHEN t.pickup_city IN ('Danang', 'Hue') THEN 'Central'
            WHEN t.pickup_city = 'Saigon' THEN 'South'
            ELSE 'Unknown'
        END AS region
    FROM trips t
    JOIN drivers d ON t.driver_id = d.driver_id
)
SELECT
    CASE
        WHEN GROUPING(region) = 1 THEN 'PLATFORM TOTAL'
        ELSE region
    END AS region_label,
    CASE
        WHEN GROUPING(region) = 1 THEN 'Grand total or average'
        ELSE 'Regional subtotal / avg'
    END AS row_type,
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END)
        AS rider_no_shows,
    (100.0 * COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END)
           / COUNT(*))::numeric(10,2) AS failure_rate,
    AVG(NULLIF(fare_amount, 0))::numeric(10,2) AS avg_positive_fare,
    SUM(fare_amount)::numeric(10,2) AS fare_sum,
    AVG(avg_rating)::numeric(10,2) AS avg_driver_rating
FROM trip_regions
GROUP BY ROLLUP(region, pickup_city)
HAVING GROUPING(pickup_city) = 1
ORDER BY GROUPING(region), region_label;

-- Part B2 What are the regional subtotals by pickup city? What is the platform-wide grand total or average?
--    Region = trip pickup city.
--    Rows where row_type = 'City subtotal / avg' are the subtotals (one per region).
--    The single row with row_type = 'Grand total or average' is the platform-wide total.

--    Findings: Hue 4/40 = 10.00% (highest); Hanoi 3/38 = 7.89%;
--    Haiphong 3/39 = 7.69%; Saigon 1/40 = 2.50%;
--    Danang 1/43 = 2.33% (lowest); platform 12/200 = 6.00%.

--    Requirement: subtotals per region and a platform grand total.
--    Do not include individual detail rows.
--    Note identifying which rows are the subtotals and which is the grand total.
--    Notes: avg_driver_rating weights each driver's rating by trip count; it is
--    NOT the average of distinct drivers' ratings.
--    Zero fare trips are omitted only from avg_positive_fare.

SELECT
    CASE
        WHEN GROUPING(t.pickup_city) = 1 THEN 'PLATFORM TOTAL'
        ELSE t.pickup_city
    END AS city,
    CASE
        WHEN GROUPING(t.pickup_city) = 1 THEN 'Grand total or average'
        ELSE 'City subtotal / avg'
    END AS row_type,
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END)
        AS rider_no_shows,
    (100.0 * COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END)
           / COUNT(*))::numeric(10,2) AS failure_rate,
    AVG(NULLIF(t.fare_amount, 0))::numeric(10,2) AS avg_positive_fare,
    SUM(t.fare_amount)::numeric(10,2) AS fare_sum,
    AVG(d.avg_rating)::numeric(10,2) AS avg_driver_rating
FROM trips t
JOIN drivers d ON t.driver_id = d.driver_id
GROUP BY ROLLUP(t.pickup_city)
ORDER BY GROUPING(t.pickup_city), failure_rate DESC, city;

-- Part C: Among our high-volume (more trips than average) drivers, what were their no-show statistics,
--    and how did each of these drivers compare to the high-volume group as a whole?

--    Findings: 8 drivers, 145 trips, 7 no-shows; group no-show rate = 4.83%.
--    Driver 2: 3/16 = 18.75%, 13.92 percentage points above the group.
--    Driver 6: 1/21 = 4.76%, 0.07 points below the group.
--    Drivers 5, 8 and 10 had no rider no-shows in this subset.

--    Requirement: baseline for evaluating high-volume producers.
--    WITH clause to create an intermediate result that summarizes performance for each producer (driver).
--    Second aggregation or filter to calculate a baseline for high-volume producers (drivers).

--    Notes: 'High-volume' means more trips than the mean among the 13 drivers with
--    recorded trips (200/13 = 15.38). Eight drivers qualify.
--    The benchmark pools 7 no-shows across 145 trips (4.83%) from eight
--    drivers with more trips than the trip-holding-driver average (15.38).
--    Their own trips contribute to the benchmark; expected counts are
--    reference calculations, not predictions of future no-shows.
--    Group rate = 100 x SUM(no-shows) / SUM(trips), not an unweighted
--    average of driver percentages. A driver's data is INCLUDED in the
--    comparison group; benchmark counts are illustrations, NOT predictions.
--    The displayed driver rating is descriptive only.

WITH driver_summary AS (
    SELECT
        t.driver_id,
        d.avg_rating AS driver_rating,
        COUNT(*) AS total_trips,
        COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END)
            AS rider_no_shows,
        100.0 * COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END)
              / COUNT(*) AS failure_rate
    FROM trips t
    JOIN drivers d ON t.driver_id = d.driver_id
    GROUP BY t.driver_id, d.avg_rating
),
high_volume AS (
    SELECT *
    FROM driver_summary
    WHERE total_trips > (SELECT AVG(total_trips) FROM driver_summary)
),
baseline AS (
    SELECT
        100.0 * SUM(rider_no_shows) / SUM(total_trips) AS baseline_rate,
        (SELECT AVG(total_trips) FROM driver_summary) AS avg_trips
    FROM high_volume
)
SELECT
    h.driver_id,
    h.total_trips,
    h.rider_no_shows AS actual_no_shows,
    h.failure_rate::numeric(10,2) AS failure_rate,
    b.baseline_rate::numeric(10,2) AS baseline_rate,
    (h.failure_rate - b.baseline_rate)::numeric(10,2) AS diff_pct_points,
    (h.total_trips * b.baseline_rate / 100)::numeric(10,2)
        AS expected_no_shows,
    (h.rider_no_shows - h.total_trips * b.baseline_rate / 100)::numeric(10,2)
        AS actual_minus_expected,
    h.driver_rating,
    b.avg_trips::numeric(10,2) AS avg_trips
FROM high_volume h
CROSS JOIN baseline b
ORDER BY h.failure_rate DESC, h.driver_id ASC;


-- ============================================================================
-- EXTRA CHECKS | Exploratory, not required for the driver-performance finding
-- These show possible questions for a later investigation. Only 12 trips were
-- rider no-shows, so none of these comparisons establishes a cause or a trend.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Part D1: Did any rider have more than one no-show, and were the trips
--    associated with the same or different drivers?

--    Findings: Rider 1: 2 no-shows in 13 trips, involving 2 different drivers;
--    rider 21: 2 in 8 trips, also involving 2 different drivers.
--    Together they account for 4 of the platform's 12 no-shows.

--    Notes: This is descriptive rider context, not evidence of who caused an event.
--    Tools: Conditional COUNT and COUNT(DISTINCT CASE WHEN ...) per rider;
--    HAVING keeps riders with at least two no-shows.
-- ----------------------------------------------------------------------------

SELECT
    rider_id,
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END)
        AS rider_no_shows,
    COUNT(DISTINCT CASE WHEN cancellation_reason = 'Rider no show'
                        THEN driver_id END) AS drivers_on_no_show_trips
FROM trips
GROUP BY rider_id
HAVING COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END) >= 2
ORDER BY rider_no_shows DESC, rider_id ASC;

-- ----------------------------------------------------------------------------
-- Part D2:  How do recorded no-show rates differ across surge multipliers?

--    Findings: 1.00: 3/99 = 3.03%; 1.25: 7/46 = 15.22%;
--    1.50: 0/29 = 0.00%; 2.00: 2/26 = 7.69%.
--    There's an uptick at 1.25, but we don't have sufficient evidence to
--    indicate that surge pricing caused any no-show.

--    Notes: Different group sizes and only 12 failures prevent a causal reading.
--    Tools: GROUP BY surge_multiplier and conditional COUNT in each group.

-- ----------------------------------------------------------------------------
SELECT
    surge_multiplier,
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END)
        AS rider_no_shows,
    (100.0 * COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END)
           / COUNT(*))::numeric(10,2) AS failure_rate
FROM trips
GROUP BY surge_multiplier
ORDER BY surge_multiplier;
