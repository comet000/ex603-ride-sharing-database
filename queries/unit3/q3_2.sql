-- ============================================================
-- Task 3.2: Find the bug
-- Theme: RideSharing   Database: ex603_data
-- ============================================================


-- ############################################################
-- PART A: The rows that vanished
-- ############################################################
-- Nullable column used: trips.cancellation_reason.
-- 166 of 200 trips already have NULL there, so no rows were inserted.


-- 3.2A-1 The broken query: count of trips whose cancellation reason is not 'Rider no show.'
--    Requirement: inequality predicate on a nullable column.
--    Result is 22 trips.
SELECT COUNT(*) AS not_rider_no_show
FROM trips
WHERE cancellation_reason != 'Rider no show';


-- 3.2A-2 All rows the broken query silently omitted.
--    Requirement: count of omitted rows.
--    Result is 188 expected, 22 returned with the broken query, therefore 166 omitted.
SELECT
    COUNT(*) AS total_trips,
    COUNT(*) FILTER (
        WHERE cancellation_reason = 'Rider no show'
    ) AS rider_no_shows,
    COUNT(*) - COUNT(*) FILTER (
        WHERE cancellation_reason = 'Rider no show'
    ) AS expected_not_rider_no_show,
    COUNT(*) - COUNT(*) FILTER (
        WHERE cancellation_reason = 'Rider no show'
    ) - COUNT(*) FILTER (
        WHERE cancellation_reason != 'Rider no show'
    ) AS silently_omitted
FROM trips;


-- 3.2A-3 The counts do not sum to the table total. A comparison is TRUE,
--    FALSE, or UNKNOWN, and != plus = covers only two of the three.
--    Requirement: both counts and the table total together.
--    Result: 22 + 12 = 34, which is not 200. Add the 166 and it is 200.
WITH counts AS (
  SELECT
    (SELECT COUNT(*) FROM trips WHERE cancellation_reason != 'Rider no show') AS true_not_equal,
    (SELECT COUNT(*) FROM trips WHERE cancellation_reason = 'Rider no show')  AS false_equal,
    (SELECT COUNT(*) FROM trips WHERE cancellation_reason IS NULL)            AS unknown_null,
    (SELECT COUNT(*) FROM trips)                                              AS table_total
)
SELECT
  true_not_equal,
  false_equal,
  true_not_equal + false_equal                AS sum_of_two_groups,
  unknown_null,
  true_not_equal + false_equal + unknown_null AS sum_of_all_three,
  table_total
FROM counts;


-- 3.2A-4 The repaired first query handling NULL explicitly with IS NULL.
--    Requirement: IS NULL (or COALESCE).
--    Result is 188 rows (22 + 166). The 12 rider no-shows stay out, which
--    is what I wanted.
SELECT COUNT(*) AS not_rider_no_show
FROM trips
WHERE cancellation_reason IS NULL
   OR cancellation_reason != 'Rider no show';


-- 3.2A-5 The repaired broken query with COALESCE: a blank reason becomes a label that
--    can never equal 'Rider no show', so the row is kept.
--    Result is 188 rows, same as 3.2A-4.
SELECT COUNT(*) AS not_rider_no_show
FROM trips
WHERE COALESCE(cancellation_reason, 'No reason provided') != 'Rider no show';


-- ############################################################
-- PART B: The alias that did not exist yet
-- Question: Which trips were recorded as rider no-shows?
-- ############################################################

-- 3.2B-1 The failing query: Which trips were recorded as rider no-shows?
--    Requirement: An alias defined in SELECT, used in WHERE.
--    Execution order is FROM -> WHERE -> SELECT, so rider_no_show does
--    not exist yet when WHERE runs.
--    ERROR MESSAGE (verbatim):
--      [42703] ERROR: column "rider_no_show" does not exist
--        Position: 170
SELECT
    trip_id,
    cancellation_reason,
    CASE
        WHEN cancellation_reason = 'Rider no show' THEN 1
        ELSE 0
    END AS rider_no_show
FROM trips
WHERE rider_no_show = 1;


-- 3.2B-2 Rewrite 1: The successful query: Which trips were recorded as rider no-shows?
--    Requirement: Repeat the expression in WHERE.
--    Result is 12 rows.
SELECT
    trip_id,
    cancellation_reason,
    CASE
        WHEN cancellation_reason = 'Rider no show' THEN 1
        ELSE 0
    END AS rider_no_show
FROM trips
WHERE CASE
          WHEN cancellation_reason = 'Rider no show' THEN 1
          ELSE 0
      END = 1
ORDER BY trip_id;


-- 3.2B-3 Rewrite 2: The successful query: Which trips were recorded as rider no-shows?
--    Requirement: Wrap in a CTE so the alias becomes a real column.
--    Result is the same 12 rows as 3.2B-2.
WITH trip_outcomes AS (
    SELECT
        trip_id,
        cancellation_reason,
        CASE
            WHEN cancellation_reason = 'Rider no show' THEN 1
            ELSE 0
        END AS rider_no_show
    FROM trips
)
SELECT
    trip_id,
    cancellation_reason,
    rider_no_show
FROM trip_outcomes
WHERE rider_no_show = 1
ORDER BY trip_id;
