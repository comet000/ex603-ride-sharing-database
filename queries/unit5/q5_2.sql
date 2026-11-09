-- ============================================================================
-- Task 5.2 | Find Records That Joins May Exclude
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- An event is a recorded trip, including a cancelled trip.
-- ============================================================================

-- Part A | Compare INNER JOIN and LEFT JOIN

-- 5.2 A1 | Question: How many trips does each driver have, including zero?
-- Findings: All 15 drivers appear. Drivers 14 and 15 each have zero trips.
-- Notes: COUNT(t.trip_id), not COUNT(*), returns zero for unmatched drivers.
--        The ungrouped LEFT JOIN has 202 rows: 200 trips plus 2 driver-only
--        rows. GROUP BY produces one report row per driver.
-- Requirement: "Use LEFT JOIN to return all producers, including those who
--               have never had an event."
SELECT
    d.driver_id,
    d.driver_name,
    COUNT(t.trip_id) AS trip_count
FROM drivers d
    LEFT JOIN trips t ON t.driver_id = d.driver_id
GROUP BY d.driver_id, d.driver_name
ORDER BY d.driver_id;


-- 5.2 A2 | Question: Which drivers have at least one trip, and how many?
-- Findings: Only 13 drivers appear. Drivers 14 and 15 are excluded;
--           the other drivers have the same trip counts as in A1.
-- Requirement: "Write an equivalent query using INNER JOIN."
SELECT
    d.driver_id,
    d.driver_name,
    COUNT(t.trip_id) AS trip_count
FROM drivers d
    INNER JOIN trips t ON t.driver_id = d.driver_id
GROUP BY d.driver_id, d.driver_name
ORDER BY d.driver_id;


-- 5.2 A3 | Question: How many distinct drivers does INNER JOIN exclude?
-- Findings: LEFT JOIN: 15 drivers; INNER JOIN: 13; excluded: 2.
-- Notes: COUNT(DISTINCT d.driver_id) prevents multiple trips from counting
--        the same driver more than once.
-- Requirement: "Compare the results and determine how many producers are
--               excluded by the inner join."
SELECT
    l.driver_count AS drivers_in_left_join,
    i.driver_count AS drivers_in_inner_join,
    l.driver_count - i.driver_count AS drivers_excluded_by_inner_join
FROM (
    SELECT COUNT(DISTINCT d.driver_id) AS driver_count
    FROM drivers d
        LEFT JOIN trips t ON t.driver_id = d.driver_id
) AS l
CROSS JOIN (
    SELECT COUNT(DISTINCT d.driver_id) AS driver_count
    FROM drivers d
        INNER JOIN trips t ON t.driver_id = d.driver_id
) AS i;


-- 5.2 A4 | Question: Which drivers are missing from INNER JOIN, and why?
-- Findings: Driver 14: Saigon; onboarded 2022-04-11; rating 3.63.
--           Driver 15: Hue; onboarded 2022-11-18; rating 4.00.
--           Both are marked active and have no trips in this dataset,
--           which covers 2023. Their ratings' source and timing are unknown.
-- Notes: The INNER JOIN excludes them because they have no matching trip,
--        not because their current activity flag is false. Their lack of
--        recorded trips does not establish why they have no activity.
-- Requirement: "Explain which producers are missing and why."
SELECT
    d.driver_id,
    d.driver_name,
    d.home_city,
    d.onboard_date,
    d.is_active,
    d.avg_rating
FROM drivers d
    LEFT JOIN trips t ON t.driver_id = d.driver_id
WHERE t.trip_id IS NULL
ORDER BY d.driver_id;


-- Part B | Explore RIGHT JOIN and FULL OUTER JOIN

-- 5.2 B1 | Question: Does RIGHT JOIN return the same driver counts as A1?
-- Findings: All 15 drivers appear, including 14 and 15 with zero trips.
-- Requirement: "Write a RIGHT JOIN that returns the same records as your
--               LEFT JOIN from Part A."
SELECT
    d.driver_id,
    d.driver_name,
    COUNT(t.trip_id) AS trip_count
FROM trips t
    RIGHT JOIN drivers d ON t.driver_id = d.driver_id
GROUP BY d.driver_id, d.driver_name
ORDER BY d.driver_id;


-- 5.2 B2 | Question: Are the entire LEFT and RIGHT JOIN reports identical?
-- Findings: Both contain 15 rows. No rows differ in either direction.
-- Notes: EXCEPT compares driver_id, driver_name, AND trip_count, not just
--        the number of rows. IDs are unique in each grouped result, so a
--        two-way empty difference establishes equality of these reports.
-- Requirement: "Compare the results to confirm that they match."
WITH left_results AS (
    SELECT
        d.driver_id,
        d.driver_name,
        COUNT(t.trip_id) AS trip_count
    FROM drivers d
        LEFT JOIN trips t ON t.driver_id = d.driver_id
    GROUP BY d.driver_id, d.driver_name
),
right_results AS (
    SELECT
        d.driver_id,
        d.driver_name,
        COUNT(t.trip_id) AS trip_count
    FROM trips t
        RIGHT JOIN drivers d ON t.driver_id = d.driver_id
    GROUP BY d.driver_id, d.driver_name
),
left_only AS (
    SELECT * FROM left_results
    EXCEPT
    SELECT * FROM right_results
),
right_only AS (
    SELECT * FROM right_results
    EXCEPT
    SELECT * FROM left_results
)
SELECT
    (SELECT COUNT(*) FROM left_results) AS left_rows,
    (SELECT COUNT(*) FROM right_results) AS right_rows,
    (SELECT COUNT(*) FROM left_only) AS left_only_rows,
    (SELECT COUNT(*) FROM right_only) AS right_only_rows;


-- 5.2 B3 | Question: Which driver-trip records match, and which do not?
-- Findings: 202 rows: 200 matches, 2 unmatched drivers (14 and 15),
--           and no trips without a driver record.
-- Notes: Unmatched records sort first to make them visible in screenshots.
--        The trips.driver_id foreign key prevents orphaned driver IDs.
-- Requirement: "Write a FULL OUTER JOIN that includes matching and
--               unmatched records from both tables."
SELECT
    COALESCE(d.driver_id, t.driver_id) AS driver_id,
    d.driver_name,
    t.trip_id,
    CASE
        WHEN d.driver_id IS NULL THEN 'Trip without driver record'
        WHEN t.trip_id IS NULL THEN 'Driver without trip'
        ELSE 'Matched driver and trip'
    END AS match_status
FROM drivers d
    FULL OUTER JOIN trips t ON d.driver_id = t.driver_id
ORDER BY
    CASE
        WHEN d.driver_id IS NULL OR t.trip_id IS NULL THEN 0
        ELSE 1
    END,
    COALESCE(d.driver_id, t.driver_id),
    t.trip_id;


-- 5.2 B4 | Question: What does FULL OUTER JOIN reveal from both sides?
-- Findings: 200 matched driver-trip rows, 2 driver-only rows, 0 trip-only
--           rows: 202 total. The zero trip-only count is expected because
--           the trips.driver_id foreign key requires a matching driver.
-- Notes: A LEFT JOIN with drivers first retains all drivers, while the
--        corresponding RIGHT JOIN with drivers first retains all trips.
--        FULL OUTER JOIN retains unmatched rows from BOTH tables at once.
-- Requirement: "Explain what a full outer join can reveal that a left join
--               or right join alone may not show."
SELECT
    COUNT(*) FILTER (
        WHERE d.driver_id IS NOT NULL AND t.trip_id IS NOT NULL
    ) AS matched_rows,
    COUNT(*) FILTER (
        WHERE d.driver_id IS NOT NULL AND t.trip_id IS NULL
    ) AS drivers_without_trips,
    COUNT(*) FILTER (
        WHERE d.driver_id IS NULL AND t.trip_id IS NOT NULL
    ) AS trips_without_driver,
    COUNT(*) AS total_rows
FROM drivers d
    FULL OUTER JOIN trips t ON d.driver_id = t.driver_id;


-- Part C | Find Producers with No Events Using Two Approaches

-- 5.2 C1 | Question: Which drivers have never had a recorded trip?
-- Findings: Drivers 14 and 15.
-- Notes: NOT EXISTS tests each driver for the absence of a matching trip
--        and can return the driver's name alongside the ID.
-- Requirement: "Write two queries that identify producers who have never
--               had an event and compare them." Approach: "NOT EXISTS."
SELECT
    d.driver_id,
    d.driver_name
FROM drivers d
WHERE NOT EXISTS (
    SELECT 1
    FROM trips t
    WHERE t.driver_id = d.driver_id
)
ORDER BY d.driver_id;


-- 5.2 C2 | Question: Which drivers have no trips, using set subtraction?
-- Findings: Drivers 14 and 15, matching C1.
-- Notes: EXCEPT subtracts trip driver IDs from all driver IDs and removes
--        duplicates. Joining to drivers adds the names for readability.
-- Requirement: "Write two queries that identify producers who have never
--               had an event and compare them." Approach: "EXCEPT."
SELECT
    d.driver_id,
    d.driver_name
FROM drivers d
    INNER JOIN (
        SELECT driver_id FROM drivers
        EXCEPT
        SELECT driver_id FROM trips
    ) AS no_trip_ids ON no_trip_ids.driver_id = d.driver_id
ORDER BY d.driver_id;


-- 5.2 C3 | Question: Do NOT EXISTS and EXCEPT identify exactly the same IDs?
-- Findings: Both return 2 drivers; neither result contains an ID missing
--           from the other. NOT EXISTS checks for matching rows, whereas
--           EXCEPT computes the difference between two sets of IDs.
-- Notes: Checking both set differences verifies exact ID equality, not
--        just equal counts.
-- Requirement: "Run both queries and compare their results. In one or two
--               sentences, explain how the approaches differ and confirm
--               whether they identify the same producers."
WITH not_exists_results AS (
    SELECT d.driver_id
    FROM drivers d
    WHERE NOT EXISTS (
        SELECT 1
        FROM trips t
        WHERE t.driver_id = d.driver_id
    )
),
except_results AS (
    SELECT driver_id FROM drivers
    EXCEPT
    SELECT driver_id FROM trips
),
not_exists_only AS (
    SELECT driver_id FROM not_exists_results
    EXCEPT
    SELECT driver_id FROM except_results
),
except_only AS (
    SELECT driver_id FROM except_results
    EXCEPT
    SELECT driver_id FROM not_exists_results
)
SELECT
    (SELECT COUNT(*) FROM not_exists_results) AS not_exists_count,
    (SELECT COUNT(*) FROM except_results) AS except_count,
    (SELECT COUNT(*) FROM not_exists_only) AS only_in_not_exists,
    (SELECT COUNT(*) FROM except_only) AS only_in_except;
