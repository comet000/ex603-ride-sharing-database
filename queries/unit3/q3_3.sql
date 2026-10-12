-- ============================================================
-- Task 3.3: Hand the team a corrected query
-- Theme: RideSharing   Database: ex603_data
-- ============================================================
-- Two-step question: Which drivers were involved in at least
-- one trip recorded as a rider no-show, and how many of those
-- trips did each driver have?
-- Step 1: Find trips with cancellation_reason = 'Rider no show'.
-- Step 2: Find their drivers and count those trips per driver.
-- ============================================================

-- 3.3a Form 1: Which drivers had recorded rider no-shows,
--    and how many did each driver have?
--    Requirement: subquery using IN.
--    Result is 9 drivers and their no-show counts total 12.
SELECT
    drivers.driver_id,
    drivers.driver_name,
    (
        SELECT COUNT(*)
        FROM trips
        WHERE trips.driver_id = drivers.driver_id
          AND trips.cancellation_reason = 'Rider no show'
    ) AS rider_no_show_count
FROM drivers
WHERE drivers.driver_id IN (
    SELECT driver_id
    FROM trips
    WHERE cancellation_reason = 'Rider no show'
)
ORDER BY drivers.driver_id;


-- 3.3b Form 2: Which drivers had recorded rider no-shows,
--    and how many did each driver have?
--    Requirement: Common Table Expression using WITH.
--    Result is the same drivers and no-show counts as 3.3a.
WITH no_show_trips AS (
    SELECT
        driver_id,
        trip_id
    FROM trips
    WHERE cancellation_reason = 'Rider no show'
)
SELECT
    drivers.driver_id,
    drivers.driver_name,
    (
        SELECT COUNT(*)
        FROM no_show_trips
        WHERE no_show_trips.driver_id = drivers.driver_id
    ) AS rider_no_show_count
FROM drivers
WHERE drivers.driver_id IN (
    SELECT driver_id
    FROM no_show_trips
)
ORDER BY drivers.driver_id;


-- 3.3c Form 3: Which drivers had recorded rider no-shows,
--    and how many did each driver have?
--    Requirement: a third, distinct subquery form. (EXISTS)
--    EXISTS asks whether at least one matching trip exists.
--    Result is the same drivers and no-show counts as 3.3a and 3.3b.
SELECT
    drivers.driver_id,
    drivers.driver_name,
    (
        SELECT COUNT(*)
        FROM trips
        WHERE trips.driver_id = drivers.driver_id
          AND trips.cancellation_reason = 'Rider no show'
    ) AS rider_no_show_count
FROM drivers
WHERE EXISTS (
    SELECT 1
    FROM trips
    WHERE trips.driver_id = drivers.driver_id
      AND trips.cancellation_reason = 'Rider no show'
)
ORDER BY drivers.driver_id;


-- 3.3d Verification that all three forms return identical result sets.
--    Requirement: demonstrate that all three forms return
--    identical result sets. Show that the rows themselves match.
--    Results confirm they match.
WITH
no_show_trips AS (
    SELECT driver_id
    FROM trips
    WHERE cancellation_reason = 'Rider no show'
),
form1 AS (
    SELECT
        d.driver_id,
        d.driver_name,
        (SELECT COUNT(*)
         FROM trips t
         WHERE t.driver_id = d.driver_id
           AND t.cancellation_reason = 'Rider no show') AS cnt
    FROM drivers d
    WHERE d.driver_id IN (
    SELECT driver_id
    FROM trips
    WHERE cancellation_reason = 'Rider no show'
)
),
form2 AS (
    SELECT
        d.driver_id,
        d.driver_name,
        (SELECT COUNT(*)
         FROM no_show_trips n
         WHERE n.driver_id = d.driver_id) AS cnt
    FROM drivers d
    WHERE d.driver_id IN (SELECT driver_id FROM no_show_trips)
),
form3 AS (
    SELECT
        d.driver_id,
        d.driver_name,
        (SELECT COUNT(*)
         FROM trips t
         WHERE t.driver_id = d.driver_id
           AND t.cancellation_reason = 'Rider no show') AS cnt
    FROM drivers d
    WHERE EXISTS (
        SELECT 1
        FROM trips t
        WHERE t.driver_id = d.driver_id
          AND t.cancellation_reason = 'Rider no show'
    )
)
SELECT
    COALESCE(f1.driver_id, f2.driver_id, f3.driver_id) AS driver_id,
    COALESCE(f1.driver_name, f2.driver_name, f3.driver_name) AS driver_name,
    f1.cnt AS form1_count,
    f2.cnt AS form2_count,
    f3.cnt AS form3_count,
    CASE
        WHEN f1.driver_id IS NOT NULL
         AND f2.driver_id IS NOT NULL
         AND f3.driver_id IS NOT NULL
         AND f1.driver_name IS NOT DISTINCT FROM f2.driver_name
         AND f1.driver_name IS NOT DISTINCT FROM f3.driver_name
         AND f1.cnt = f2.cnt
         AND f1.cnt = f3.cnt
        THEN 'MATCH'
        ELSE 'DIFFERENT'
    END AS rows_match
FROM form1 f1
FULL OUTER JOIN form2 f2
    ON f1.driver_id = f2.driver_id
FULL OUTER JOIN form3 f3
    ON COALESCE(f1.driver_id, f2.driver_id) = f3.driver_id
ORDER BY driver_id;


-- 3.3e Equivalence caveat: NULL values.
--    Requirement: name one input condition under which the three
--    forms would not be equivalent.
--    Input condition: A subquery returns a NULL driver_id.
--
--    If the question were reversed to find drivers with no
--    rider no-show trips, NOT IN and NOT EXISTS could disagree.
--    A NULL in the NOT IN subquery causes nonmatching driver IDs
--    to evaluate to UNKNOWN, excluding drivers who should qualify.
--    NOT EXISTS does not have this problem.
--
--    The three submitted forms (IN, CTE, and EXISTS) ask the
--    positive question, so they remain equivalent. This NULL
--    issue applies to negative membership queries. The current
--    schema also prevents NULLs in trips.driver_id.
--
--    The example below demonstrates the effect of adding NULL
--    to a NOT IN list: 13 drivers qualify without NULL, but
--    none qualify when NULL is included.

SELECT
    (SELECT COUNT(*)
     FROM drivers
     WHERE driver_id NOT IN (1, 2)) AS without_null,
    (SELECT COUNT(*)
     FROM drivers
     WHERE driver_id NOT IN (1, 2, NULL)) AS with_null;
