-- ============================================================================
-- Task 5.3 | Understand Join Performance and Execution Plans
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- ============================================================================

-- Part A | Explore CROSS JOIN

-- 5.3 A1 | Question: How many drivers and badge types are there?
-- Findings: 15 drivers and 5 badge types.
-- Requirement: "Count the rows in each source table."
SELECT
    (SELECT COUNT(*) FROM drivers) AS driver_count,
    (SELECT COUNT(*) FROM driver_badges) AS badge_type_count;


-- 5.3 A2 | Question: What are all possible driver-badge combinations?
-- Findings: 75 rows, pairing each of 15 drivers with all 5 badge types.
-- Notes: These are possible combinations, not recorded badge awards.
-- Requirement: "Run the CROSS JOIN and count the resulting rows."
SELECT
    d.driver_id,
    b.badge_name
FROM drivers d
    CROSS JOIN driver_badges b
ORDER BY d.driver_id, b.badge_name;


-- 5.3 A3 | Question: Does the CROSS JOIN count equal the product of the
--                     two source-table counts?
-- Findings: 15 x 5 = 75; the CROSS JOIN also returns 75; counts match.
-- Requirement: "Show how the result matches the multiplication of the two
--               source table counts."
SELECT
    dr.n AS driver_rows,
    bd.n AS badge_rows,
    dr.n * bd.n AS expected_rows,
    cj.n AS cross_join_rows,
    CASE WHEN dr.n * bd.n = cj.n THEN 'Yes' ELSE 'No' END AS counts_match
FROM (SELECT COUNT(*) AS n FROM drivers) dr
    CROSS JOIN (SELECT COUNT(*) AS n FROM driver_badges) bd
    CROSS JOIN (
        SELECT COUNT(*) AS n
        FROM drivers CROSS JOIN driver_badges
    ) cj;


-- 5.3 A4 | Question: When is a Cartesian product useful or an error?
-- Findings: A complete driver-badge grid includes combinations not yet
--           awarded, which A5 examines. A missing join condition may
--           accidentally multiply rows: 200 trips x 15 drivers would
--           yield 3,000 pairs, rather than 200 actual driver-trip links.
-- Requirement: "Explain when a Cartesian product might be useful and when
--               it could indicate a query error."


-- 5.3 A5 (supplementary) | Question: How many badge types have not been
--                                 awarded to each driver?
-- Findings: Of 75 possible driver-badge pairs, 25 are awarded and 50 are
--           unawarded. Drivers 13, 14, and 15 each have 5 unawarded badges;
--           driver 10 has 1 unawarded badge.
-- Notes: CROSS JOIN makes the full grid; NOT EXISTS excludes pairs found
--        in driver_badge_awards. An absent award does not mean a driver
--        qualifies to earn that badge.
-- Requirement: "Explain when a Cartesian product might be useful and when
--               it could indicate a query error." (Additional example.)
SELECT
    d.driver_id,
    COUNT(*) AS badges_not_yet_awarded
FROM drivers d
    CROSS JOIN driver_badges b
WHERE NOT EXISTS (
    SELECT 1
    FROM driver_badge_awards a
    WHERE a.driver_id = d.driver_id
      AND a.badge_id = b.badge_id
)
GROUP BY d.driver_id
ORDER BY badges_not_yet_awarded DESC, d.driver_id;


-- Part B | Examine a Query Execution Plan

-- 5.3 B1 | Question: How does PostgreSQL plan the three-table join in 5.1 Q1?
-- Findings: Fill in using the full EXPLAIN plan from your own PostgreSQL run.
-- Notes: The SELECT below is IDENTICAL to 5.1 Q1, including the output
--        expressions and ORDER BY. EXPLAIN reports estimates, not timings.
-- Requirement: "Capture the full execution plan."
EXPLAIN
SELECT
    t.trip_id,
    r.rider_id,
    r.rider_name AS rider_name,
    d.driver_id,
    d.driver_name AS driver_name,
    t.requested_at,
    COALESCE(
        TO_CHAR(t.completed_at, 'YYYY-MM-DD HH24:MI:SS'),
        'Not completed'
    ) AS completed_at,
    t.trip_status,
    COALESCE(t.cancellation_reason, 'Not cancelled') AS cancellation_reason
FROM trips t
    INNER JOIN riders r ON t.rider_id = r.rider_id
    INNER JOIN drivers d ON t.driver_id = d.driver_id
ORDER BY t.requested_at, t.trip_id;


-- 5.3 B1 (optional) | Question: What are the actual execution timings?
-- Findings: Fill in only if you choose to run EXPLAIN ANALYZE.
-- Notes: EXPLAIN ANALYZE actually executes this read-only SELECT.
-- Requirement: "You may also use EXPLAIN ANALYZE to measure actual execution
--               behavior."
-- Uncomment this complete statement only if you want measured timings:
-- EXPLAIN ANALYZE
-- SELECT
--     t.trip_id,
--     r.rider_id,
--     r.rider_name AS rider_name,
--     d.driver_id,
--     d.driver_name AS driver_name,
--     t.requested_at,
--     COALESCE(
--         TO_CHAR(t.completed_at, 'YYYY-MM-DD HH24:MI:SS'),
--         'Not completed'
--     ) AS completed_at,
--     t.trip_status,
--     COALESCE(t.cancellation_reason, 'Not cancelled') AS cancellation_reason
-- FROM trips t
--     INNER JOIN riders r ON t.rider_id = r.rider_id
--     INNER JOIN drivers d ON t.driver_id = d.driver_id
-- ORDER BY t.requested_at, t.trip_id;


-- 5.3 B2 | Question: Which join algorithms did PostgreSQL choose?
-- Findings: To be completed from the current EXPLAIN output. Record the
--           actual join nodes (Nested Loop, Hash Join, or Merge Join),
--           plus any scan and sort nodes. Do not reuse an older plan.
-- Requirement: "Identify the join algorithm or algorithms used, such as
--               Nested Loop, Hash Join, or Merge Join."


-- 5.3 B3 | Question: Why might PostgreSQL have chosen those algorithms?
-- Findings: To be completed using the observed plan, estimated row counts,
--           costs, and any scan/index nodes it contains.
-- Notes: The source tables have 200 trips, 30 riders, and 15 drivers.
--        rideshare.sql defines primary keys on trips.trip_id,
--        riders.rider_id, and drivers.driver_id. It does not define
--        separate indexes on trips.rider_id, trips.driver_id, or
--        trips.requested_at. PostgreSQL does not index FKs automatically.
--        Possible explanations to check against YOUR plan:
--        * Hash Join can be inexpensive for small equality-join inputs.
--        * Nested Loop can be efficient with indexed inner lookups.
--        * ORDER BY may introduce a Sort node.
--        These are possibilities, not claims about the observed plan.
-- Requirement: "Explain why PostgreSQL may have selected these algorithms,
--               considering table sizes and available indexes."


-- 5.3 B4 | Question: Which operations might become slower as data grows?
-- Findings: Predictions to revise using the observed plan: scans of a
--           growing trips table may read more rows; repeated Nested Loop
--           lookups may cost more with a large outer input; sorting many
--           joined rows may need more memory or disk space. A large Hash
--           Join build side can also spill to disk.
-- Notes: Larger tables, new indexes, or changed match selectivity can
--        cause PostgreSQL to choose a different algorithm. Mention only
--        plan nodes that actually appear when describing this specific run.
-- Requirement: "Predict which part of the query might become less efficient
--               as the dataset grows."
