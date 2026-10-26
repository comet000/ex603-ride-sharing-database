-- ============================================================
-- Task 4.1: Measure the platform
-- Theme: RideSharing   Database: ex603_data
-- ============================================================
-- Calculate the platform's actual performance metrics
-- and examine how they vary across producers.
-- ============================================================

-- 1a: What are the fare statistics across all trips, and how many unique riders are there?

--    Findings: 200 fares, totaling $3628.19, with a minimum of $0,
--    average of $18.14, and maximum of $70.86. Number of distinct riders is 30.

--    Requirement: count, total, average, minimum, maximum
--    of the fare_amount metric, and how many distinct riders appear.
--    Notes: The minimum fare is 0 because these statistics include cancelled trips.

SELECT
    COUNT(fare_amount) AS fares_recorded,
    SUM(fare_amount)::numeric(10,2) AS fare_sum,
    AVG(fare_amount)::numeric(10,2) AS avg_fare,
    MIN(fare_amount) AS min_fare,
    MAX(fare_amount) AS max_fare,
    COUNT(DISTINCT rider_id) AS distinct_riders
FROM trips;

-- 1b: What are the fare statistics across all trips, excluding trips with a fare of $0,
--    and how many unique riders are there?

--    Findings: 166 fares, totaling $3628.19, with a minimum of $4.65,
--    average of $21.86, and maximum of $70.86. Number of distinct riders is 30.

--    Requirement: same as 1a, excluding fares of $0.
--    Notes: positive recorded fares do not themselves prove payments were collected;
--    (it's possible disputed charges will be reversed).

SELECT
    COUNT(fare_amount) AS nonzero_fares_recorded,
    SUM(fare_amount)::numeric(10,2) AS fare_sum,
    AVG(fare_amount)::numeric(10,2) AS avg_nonzero_fare,
    MIN(fare_amount) AS min_nonzero_fare,
    MAX(fare_amount) AS max_nonzero_fare,
    COUNT(DISTINCT rider_id) AS distinct_riders
FROM trips
WHERE fare_amount != 0;

-- 1c: Which trip outcomes have recorded fares of $0?

--    Findings: All 34 cancelled trips have $0 fares; completed and disputed trips do not have any.

--    Purpose: demonstrate why the whole-table minimum fare from 1a is $0.

SELECT
    trip_status,
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN fare_amount = 0 THEN 1 END) AS zero_fare_trips,
    SUM(fare_amount)::numeric(10,2) AS fare_sum
FROM trips
GROUP BY trip_status
ORDER BY total_trips DESC, trip_status;

-- 2a: What is the total number of trips and average fare associated with each driver?

--    Findings: results range from 6 to 21 trips, and from $11.94 to $23.06 average fare.
--    Driver 11 has the lowest average fare ($11.94); driver 5 has the highest ($23.06).
--    Driver 6 has the most trips (21), driver 4 has the least (6).

--    Requirement: event (trip) count and average metric (fare_amount)
--    for each producer (driver). Results sorted by most to fewest trips.
--    Notes: These numbers exclude drivers 14 and 15, who have 0 trips (source: q3_1.sql).

SELECT
    driver_id,
    COUNT(*) AS total_trips,
    AVG(fare_amount)::numeric(10,2) AS avg_fare
FROM trips
GROUP BY driver_id
ORDER BY total_trips DESC, driver_id ASC;

-- 2b: What is the total number of trips and average fare associated with each driver, excluding trips where the fare was $0?

--    Findings: results range from 4 to 19 trips, and from $17.36 to $29.23 average fare.
--    Driver 3 has the lowest average nonzero fare ($17.36); driver 4 has the highest ($29.23).
--    Drivers 8 and 10 tie for the most nonzero fare trips (19), driver 4 has the least (4).

--    Requirement: event (trip) count and average metric (fare_amount)
--    for each producer (driver). Results sorted by most to fewest trips.
--    Notes: These numbers exclude drivers 14 and 15, who have 0 trips (source: q3_1.sql).
--    Trips with fares of $0 are excluded.

SELECT
    driver_id,
    COUNT(*) AS nonzero_fare_trips,
    AVG(fare_amount)::numeric(10,2) AS avg_nonzero_fare
FROM trips
WHERE fare_amount != 0
GROUP BY driver_id
ORDER BY nonzero_fare_trips DESC, driver_id ASC;

-- 3: Which drivers have enough trips for a meaningful comparison of their no-show rates?

--    Findings: 10 out of the 13 drivers with trips : 2, 3, 5, 6, 7, 8, 9, 10, 11, 12.
--           Drivers 1, 4 and 13 (11, 6, 11 trips, respectively) are excluded.
--           Of those remaining, failure rates range from 0% - 18.75%.

--    Threshold: The first quartile (25th percentile) of drivers by trip volume is dropped,
--    which filters out the bottom 25% of drivers and retains the top 75% (10 of 13 drivers).
--    I chose a quartile instead of a hardcoded number so that:
--      A. The threshold updates automatically if the data changes.
--      B. Stakeholders can change the cutoff per domain expertise. For example, to drop
--         only the bottom 10%, change PERCENTILE_CONT(0.25) to PERCENTILE_CONT(0.10).
--      C. Picking a number after seeing the failure rates could introduce bias.

--    Requirement: Choose a minimum event-count threshold.
--    Use HAVING to include only producers who meet that threshold.
--    Notes: The cutoff is a sample-size screening tool, not a statistical significance test.
--    Drivers tied at the cutoff are included; the number retained may vary.
--    Drivers 14 and 15, who both have 0 trips, are excluded from the analysis.

SELECT
    driver_id,
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END) AS rider_no_shows,
    (100.0 * COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END)
           / COUNT(*))::numeric(10,2) AS failure_rate
FROM trips
GROUP BY driver_id
HAVING COUNT(*) >= (
    SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY trip_count)
    FROM (
        SELECT COUNT(*) AS trip_count
        FROM trips
        GROUP BY driver_id
    ) AS driver_counts
)
ORDER BY total_trips DESC, driver_id ASC;

-- ------------------------------------------------------------
-- NOTES FOR 4a-4d (read first)
-- Task 4.1 Q4 asks for a breakdown by two dimensions, including region.
-- 'Region' is not a column in the data and the assignment does not define it.

-- I produced 4 queries to provide leadership with the data likely to be most valuable:
--   4a  trip pickup geographical region (North / Central / South)   <- primary answer
--   4b  trip pickup city
--   4c  driver home geographical region
--   4d  driver home city

-- Geographical regions:
-- North:      Hanoi / Haiphong
-- Central:    Danang / Hue
-- South:      Saigon

-- Why 4a is primary: a rider no-show happens at the pickup, so pickup location
-- is where a regional operations leader can act on it.
-- What each pair answers:
--   4a/4b: Where are no-shows happening?
--   4c/4d: Which drivers, grouped by where they are based, have them?
--          (useful if regional leaders manage drivers and bonuses)
--
-- No volume threshold is applied here. Regional leaders should see all of their
-- drivers with trips, unless requested otherwise.
-- total_trips is shown on every row so readers can judge sample size.
-- ------------------------------------------------------------

-- 4a: How does performance vary for each driver across pick-up regions? (region = trip pickup geographical region; N/C/S Vietnam)

--    Findings: 38 pickup geographical region / driver rows across 3 regions.
--    Central and North each have 5 pickup city / unique driver positive failure rates, South has 1.
--    Driver 4's North record is 1 no-show in 2 trips (50.00%), illustrating a very small sample.

--    Requirement: group the data by two dimensions, including region.
--    Calculate the relevant summary statistics.
--    Contain one row for each combination of the two dimensions.
--    Notes: 'Performance' is ambiguous; I'm including the failure rate, sum of fares,
--    and total trips for performance evaluation.
--    The average fare excludes $0 fares.
--    Drivers 14 and 15 both have 0 trips and are absent.

SELECT
    CASE
        WHEN pickup_city IN ('Hanoi', 'Haiphong') THEN 'North'
        WHEN pickup_city IN ('Danang', 'Hue') THEN 'Central'
        WHEN pickup_city = 'Saigon' THEN 'South'
        ELSE 'Unknown'
    END AS region,
    (100.0 * COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END)
        / COUNT(*))::numeric(10,2) AS failure_rate,
    driver_id,
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END) AS rider_no_shows,
    AVG(NULLIF(fare_amount, 0))::numeric(10,2) AS avg_positive_fare,
    SUM(fare_amount)::numeric(10,2) AS fare_sum
FROM trips
GROUP BY region, driver_id
ORDER BY region, failure_rate DESC, driver_id ASC;

-- 4b: How does performance vary for each driver across regions? (region = trip pickup city)

--    Findings: 62 pickup city / driver rows across five pickup cities.
--    Hue has the most pickup city / unique driver positive failure rates (4 total).

--    Requirement: group the data by two dimensions, including region.
--    Calculate the relevant summary statistics.
--    Contain one row for each combination of the two dimensions.
--    Notes: 'Performance' is ambiguous; I'm including the failure rate, sum of fares,
--    and total trips for performance evaluation.
--    The average fare excludes $0 fares.
--    Drivers 14 and 15 both have 0 trips and are absent.

SELECT
    pickup_city,
    (100.0 * COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END)
           / COUNT(*))::numeric(10,2) AS failure_rate,
    driver_id,
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN cancellation_reason = 'Rider no show' THEN 1 END) AS rider_no_shows,
    AVG(NULLIF(fare_amount, 0))::numeric(10,2) AS avg_positive_fare,
    SUM(fare_amount)::numeric(10,2) AS fare_sum
FROM trips
GROUP BY pickup_city, driver_id
ORDER BY pickup_city, failure_rate DESC, driver_id ASC;

-- 4c: How does performance vary for each driver across regions? (region = driver home geographic region)

--    Findings: 4 drivers based in Central, 5 in North, and 4 in South Vietnam.
--    This query doesn't collapse any rows, but organizes them by driver home region.

--    Requirement: group the data by two dimensions, including region.
--    Calculate the relevant summary statistics.
--    Contain one row for each combination of the two dimensions.
--    Notes: 'Performance' is ambiguous; I'm including the failure rate, sum of fares,
--    and total trips for performance evaluation.
--    The average fare excludes $0 fares.
--    Drivers 14 and 15 both have 0 trips and are absent.

SELECT
    CASE
        WHEN d.home_city IN ('Hanoi', 'Haiphong') THEN 'North'
        WHEN d.home_city IN ('Danang', 'Hue') THEN 'Central'
        WHEN d.home_city = 'Saigon' THEN 'South'
        ELSE 'Unknown'
    END AS home_region,
    (100.0 * COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END)
        / COUNT(*))::numeric(10,2) AS failure_rate,
    t.driver_id,
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END) AS rider_no_shows,
    AVG(NULLIF(t.fare_amount, 0))::numeric(10,2) AS avg_positive_fare,
    SUM(t.fare_amount)::numeric(10,2) AS fare_sum
FROM trips t
JOIN drivers d ON t.driver_id = d.driver_id
GROUP BY home_region, t.driver_id
ORDER BY home_region, failure_rate DESC, t.driver_id ASC;

-- 4d: How does performance vary for each driver across regions? (region = driver home city)

--    Findings: Only one driver with trips is based in Danang (driver 2).
--    Saigon is home more drivers with trips than the other cities (4 total).
--    This query doesn't collapse any rows, but organizes them by driver home city.

--    Requirement: group the data by two dimensions, including region.
--    Calculate the relevant summary statistics.
--    Contain one row for each combination of the two dimensions.

--    Notes: 'Performance' is ambiguous; I'm including the failure rate, sum of fares,
--    and total trips for performance evaluation.
--    The average fare excludes $0 fares.
--    Drivers 14 and 15 both have 0 trips and are absent.


SELECT
    d.home_city,
    (100.0 * COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END)
        / COUNT(*))::numeric(10,2) AS failure_rate,
    t.driver_id,
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END) AS rider_no_shows,
    AVG(NULLIF(t.fare_amount, 0))::numeric(10,2) AS avg_positive_fare,
    SUM(t.fare_amount)::numeric(10,2) AS fare_sum
FROM trips t
JOIN drivers d ON t.driver_id = d.driver_id
GROUP BY d.home_city, t.driver_id
ORDER BY d.home_city, failure_rate DESC, t.driver_id ASC;

-- 4e: How often does a trip originate in its driver's home city or region?

--    Purpose: verify how many pickup locations map to a driver's home location,
--    to demonstrate that 4a/b would serve a different function than 4c/d to a regional manager.

--    Findings: 67 of 200 trips start in a driver's home region, 44 of 200 in a driver's home city.

WITH trip_and_home_regions AS (
    SELECT
        t.pickup_city,
        d.home_city,
        CASE
            WHEN t.pickup_city IN ('Hanoi', 'Haiphong') THEN 'North'
            WHEN t.pickup_city IN ('Danang', 'Hue') THEN 'Central'
            WHEN t.pickup_city = 'Saigon' THEN 'South'
            ELSE 'Unknown'
        END AS pickup_region,
        CASE
            WHEN d.home_city IN ('Hanoi', 'Haiphong') THEN 'North'
            WHEN d.home_city IN ('Danang', 'Hue') THEN 'Central'
            WHEN d.home_city = 'Saigon' THEN 'South'
            ELSE 'Unknown'
        END AS home_region
    FROM trips t
    JOIN drivers d ON t.driver_id = d.driver_id
)
SELECT
    COUNT(*) AS total_trips,
    COUNT(CASE WHEN pickup_city = home_city THEN 1 END) AS same_city_trips,
    COUNT(CASE WHEN pickup_region = home_region THEN 1 END) AS same_region_trips
FROM trip_and_home_regions;
