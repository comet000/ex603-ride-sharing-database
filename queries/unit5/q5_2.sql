-- ============================================================================
-- Task 5.2 | Find Records That Joins May Exclude
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- An event is any recorded trip, including a cancelled trip.
-- A producer with no events is a driver with no row in trips.
-- ============================================================================


-- Part A: Compare INNER JOIN and LEFT JOIN

-- A1: How many trips does each driver have, including drivers who have never had one?
--
--    Findings: All 15 drivers appear. Drivers 14 and 15 have trip_count 0.
--
--    Requirement: Use LEFT JOIN to return all producers, including those who have never had an
--    event.
--
--    Notes: LEFT JOIN keeps a driver even with no matching trip. COUNT(t.trip_id) counts non-NULL
--    trip ids, so an unmatched driver contributes 0. COUNT(*) would wrongly count 1.
--
SELECT
    d.driver_id,
    d.driver_name,
    COUNT(t.trip_id) AS trip_count
FROM drivers d
    LEFT JOIN trips t ON t.driver_id = d.driver_id
GROUP BY d.driver_id, d.driver_name
ORDER BY d.driver_id;


-- A2: Which drivers have at least one trip, and how many?
--
--    Findings: 13 drivers. Drivers 14 and 15 are absent; everyone else matches their A1 count.
--
--    Requirement: Write an equivalent query using INNER JOIN.
--
--    Notes: Same SELECT and grouping as A1; only the join keyword changes.
--
SELECT
    d.driver_id,
    d.driver_name,
    COUNT(t.trip_id) AS trip_count
FROM drivers d
    INNER JOIN trips t ON t.driver_id = d.driver_id
GROUP BY d.driver_id, d.driver_name
ORDER BY d.driver_id;


-- A3: How many distinct drivers does the INNER JOIN drop?
--
--    Findings: LEFT JOIN 15, INNER JOIN 13, excluded 2.
--
--    Requirement: Compare the results and determine how many producers are excluded by the inner
--    join.
--
--    Notes: COUNT(DISTINCT d.driver_id) counts producers, not trips, per the assignment hint. Each
--    subquery returns one row, so the CROSS JOIN here just lines the two counts up side by side.
--
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


-- A4: Which drivers does the INNER JOIN omit, and why?
--
--    Findings: Driver 14 (Saigon, onboarded 2022-04-11, rating 3.63, active) and driver 15 (Hue,
--    onboarded 2022-11-18, rating 4.00, active). Both have no trip in this table. The join drops
--    them for lack of a matching trip, not because is_active is false.
--
--    Requirement: Explain which producers are missing and why.
--
--    Notes: The LEFT JOIN anti-join form: keep every driver, then WHERE t.trip_id IS NULL. That
--    test has to be in WHERE, not ON, or every driver would come back with a NULL trip side. Part C
--    answers the same question with NOT EXISTS and EXCEPT.
--
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


-- Part B: Explore RIGHT JOIN and FULL OUTER JOIN

-- B1: Does a RIGHT JOIN return the same driver records and trip counts as the LEFT JOIN in A1?
--
--    Findings: The RIGHT JOIN returns the same drivers and trip counts as A1, including drivers 14
--    and 15 with zero trips.
--
--    Requirement: Write a RIGHT JOIN that returns the same records as your LEFT JOIN from Part A.
--
--    Notes: Placing drivers on the right preserves every driver, just as A1 does with drivers on the
--    left.
--
SELECT
    d.driver_id,
    d.driver_name,
    COUNT(t.trip_id) AS trip_count
FROM trips t
    RIGHT JOIN drivers d ON t.driver_id = d.driver_id
GROUP BY d.driver_id, d.driver_name
ORDER BY d.driver_id;


-- B2: Do the LEFT JOIN and RIGHT JOIN results match exactly?
--
--    Findings: Both queries return identical driver IDs, names, and trip counts. EXCEPT finds no
--    differences in either direction.
--
--    Requirement: Compare the results to confirm that they match.
--
--    Notes: Matching row counts alone would not prove that the records are identical.
--
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
    SELECT driver_id, driver_name, trip_count FROM left_results
    EXCEPT
    SELECT driver_id, driver_name, trip_count FROM right_results
),
right_only AS (
    SELECT driver_id, driver_name, trip_count FROM right_results
    EXCEPT
    SELECT driver_id, driver_name, trip_count FROM left_results
)
SELECT
    (SELECT COUNT(*) FROM left_results) AS left_rows,
    (SELECT COUNT(*) FROM right_results) AS right_rows,
    (SELECT COUNT(*) FROM left_only) AS left_only_rows,
    (SELECT COUNT(*) FROM right_only) AS right_only_rows;


-- B3: Which driver and trip rows match, and which side has rows the other side does not?
--
--    Findings: 202 rows: 200 matched, drivers 14 and 15 as 'Driver without trip', 0 rows 'Trip
--    without driver record'.
--
--    Requirement: Write a FULL OUTER JOIN that includes matching and unmatched records from both
--    tables.
--
--    Notes: FULL OUTER JOIN keeps unmatched rows from both tables in one result; COALESCE takes the
--    driver id from whichever side has it. Unmatched rows sort first so they're visible without
--    scrolling past the 200 matches.
--
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


-- B4: What can a full outer join show that one outer join cannot show by itself?
--
--    Findings: 200 matched, 2 drivers without trips, 0 trips without a driver, 202 total.
--
--    Requirement: Explain what a full outer join can reveal that a left join or right join alone
--    may not show.
--
--    Notes: A left join from drivers can't surface an orphan trip; a right join (drivers RIGHT JOIN
--    trips) can't surface a driver with no trip. A full outer join shows both directions at once.
--    The 0 on the trip side matches the foreign key (trips.driver_id is NOT NULL and references
--    drivers). It's where a broken load would show up.
--
SELECT
    COUNT(CASE
        WHEN d.driver_id IS NOT NULL AND t.trip_id IS NOT NULL THEN 1
    END) AS matched_rows,
    COUNT(CASE
        WHEN d.driver_id IS NOT NULL AND t.trip_id IS NULL THEN 1
    END) AS drivers_without_trips,
    COUNT(CASE
        WHEN d.driver_id IS NULL AND t.trip_id IS NOT NULL THEN 1
    END) AS trips_without_driver,
    COUNT(*) AS total_rows
FROM drivers d
    FULL OUTER JOIN trips t ON d.driver_id = t.driver_id;


-- Part C: Find producers with no events, two ways

-- C1: Which drivers have never had a recorded trip? (NOT EXISTS)
--
--    Findings: Drivers 14 and 15, same as A4.
--
--    Requirement: Write two queries that identify producers who have never had an event and compare
--    them. Approach: NOT EXISTS.
--
--    Notes: Correlated anti-join: the outer row stays when the inner query returns nothing.
--    SELECT 1 is enough; the subquery is only a test, not a source of columns.
--
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


-- C2: Which drivers have no trips, using set difference? (EXCEPT)
--
--    Findings: Drivers 14 and 15, same ids as C1.
--
--    Requirement: Write two queries that identify producers who have never had an event and compare
--    them. Approach: EXCEPT.
--
--    Notes: EXCEPT subtracts the driver ids in trips from the driver ids in drivers; the join back
--    to drivers is only there to show the name.
--
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


-- C3: Do NOT EXISTS and EXCEPT return the same driver ids?
--
--    Findings: Both return 2 ids, drivers 14 and 15. Neither result has an id the other lacks.
--
--    Requirement: Run both queries and compare their results. In one or two sentences, explain how
--    the approaches differ and confirm whether they identify the same producers.
--
--    Notes: NOT EXISTS tests row by row that no matching trip exists; EXCEPT subtracts one set of
--    ids from another. They can differ when the compared column is nullable. driver_id is NOT
--    NULL here, so that difference doesn't arise and both agree.
--
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


-- D1 (supplemental): Which drivers have an account status that on the surface disagrees with their trip history?
--
--    Findings: 4 drivers. 14 and 15 are active with 0 trips. 3 and 9 are inactive with 13 and 14
--    trips. Driver 3's latest request, 2023-12-28 02:28, is the latest in the whole trips table.
--
--    Notes: Not a required join type. The active flag is not why the inner join drops 14 and 15 --
--    both are marked active. The flag also has no "as of" date, so an inactive driver with trips may
--    simply have stopped afterward; that's a record to confirm, not something this query disproves.
--
SELECT
    d.driver_id,
    d.driver_name,
    d.is_active,
    COUNT(t.trip_id) AS trip_count,
    MAX(t.requested_at) AS last_requested_at
FROM drivers d
    LEFT JOIN trips t ON t.driver_id = d.driver_id
GROUP BY d.driver_id, d.driver_name, d.is_active
HAVING (d.is_active = FALSE AND COUNT(t.trip_id) > 0)
    OR (d.is_active = TRUE AND COUNT(t.trip_id) = 0)
ORDER BY d.driver_id;
