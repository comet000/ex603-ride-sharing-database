-- ============================================================================
-- Task 5.3 | Understand Join Performance and Execution Plans
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- ============================================================================


-- Part A: Explore CROSS JOIN

-- A1: How many rows are in the two tables being crossed (drivers, driver_badges)?
--
--    Findings: 15 drivers, 5 badge types.
--
--    Requirement: Count the rows in each source table.
--
SELECT
    (SELECT COUNT(*) FROM drivers) AS driver_count,
    (SELECT COUNT(*) FROM driver_badges) AS badge_type_count;


-- A2: What does every driver paired with every badge look like?
--
--    Findings: 75 rows. Each of the 15 drivers appears with all 5 badge names.
--
--    Requirement: Run the CROSS JOIN and count the resulting rows.
--
--    Notes: No ON clause, so these are possible pairs, not awards. This query doesn't read
--    driver_badge_awards, which is what records an actual award.
--
SELECT
    d.driver_id,
    d.driver_name,
    b.badge_id,
    b.badge_name
FROM drivers d
    CROSS JOIN driver_badges b
ORDER BY d.driver_id, b.badge_name;


-- A3: Is the CROSS JOIN row count the product of the two source counts?
--
--    Findings: 15 x 5 = 75, and the CROSS JOIN count is 75. Check says Yes.
--
--    Requirement: Show how the result matches the multiplication of the two source table counts.
--
SELECT
    dr.n AS driver_rows,
    bd.n AS badge_rows,
    dr.n * bd.n AS expected_rows,
    cj.n AS cross_join_rows,
    CASE
        WHEN dr.n * bd.n = cj.n THEN 'Yes'
        ELSE 'No'
    END AS counts_match
FROM (SELECT COUNT(*) AS n FROM drivers) AS dr
    CROSS JOIN (SELECT COUNT(*) AS n FROM driver_badges) AS bd
    CROSS JOIN (
        SELECT COUNT(*) AS n
        FROM drivers
            CROSS JOIN driver_badges
    ) AS cj;


-- A4: When is that product useful, and when is it a mistake?
--
--    Findings: 200 trips x 15 drivers = 3,000 pairs. The real trip-to-driver relationship has 200
--    rows, one driver per trip. A missing join condition would invent the other 2,800.
--
--    Requirement: Explain when a Cartesian product might be useful and when it could indicate a
--    query error.
--
--    Notes: A2's badge grid is a deliberate product of two small lookup tables, and useful for
--    exactly that reason. The figure below is the accidental case, computed as arithmetic so the
--    file doesn't materialize 3,000 rows.
--
SELECT
    (SELECT COUNT(*) FROM trips) AS trip_rows,
    (SELECT COUNT(*) FROM drivers) AS driver_rows,
    (SELECT COUNT(*) FROM trips) * (SELECT COUNT(*) FROM drivers)
        AS pairs_if_the_join_condition_were_missing,
    (SELECT COUNT(*) FROM trips) AS actual_trip_rows;


-- A5 (supplementary): Which driver-badge pairs are not in the awards table?
--
--    Findings: 75 possible pairs, 25 awarded, 50 not. Drivers 13-15 have all 5 badges unawarded.
--
--    Requirement: Explain when a Cartesian product might be useful and when it could indicate a
--    query error. (Additional Example)
--
--    Notes: CROSS JOIN builds the full grid, including zeros; NOT EXISTS removes pairs already in
--    driver_badge_awards. An empty cell means "no award row," not that the driver has met the badge
--    description.
--
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


-- Part B: Examine the execution plan for the Task 5.1 three-table join

-- B1a: How does PostgreSQL plan to run the three-table join?
--
--    Findings: Estimated 200 rows. The plan hash-joins trips to riders, then nested-loops to
--    drivers through Memoize and drivers_pkey, with a final Sort on requested_at, trip_id.
--
--    Requirement: Capture the full execution plan.
--
--    Notes: Same statement as 5.1 Q1, including the ORDER BY. EXPLAIN alone does not run the query
--    or report actual time.
--
--    Full EXPLAIN output from PostgreSQL:
--    Sort  (cost=36.48..36.98 rows=200 width=613)
--      Sort Key: t.requested_at, t.trip_id
--      ->  Nested Loop  (cost=12.40..28.84 rows=200 width=613)
--            ->  Hash Join  (cost=12.25..17.80 rows=200 width=314)
--                  Hash Cond: (t.rider_id = r.rider_id)
--                  ->  Seq Scan on trips t  (cost=0.00..5.00 rows=200 width=56)
--                  ->  Hash  (cost=11.00..11.00 rows=100 width=262)
--                        ->  Seq Scan on riders r  (cost=0.00..11.00 rows=100 width=262)
--            ->  Memoize  (cost=0.15..0.41 rows=1 width=262)
--                  Cache Key: t.driver_id
--                  Cache Mode: logical
--                  ->  Index Scan using drivers_pkey on drivers d  (cost=0.14..0.40 rows=1 width=262)
--                        Index Cond: (driver_id = t.driver_id)
--
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


-- B1b: What did PostgreSQL actually do when it ran that join?
--
--    Findings: 200 rows came back, matching the estimate. The rider scan returned 30 rows against
--    an estimate of 100. Memoize handled 200 lookups with 187 hits / 13 misses (13 index searches).
--    Sort was quicksort, in memory, 46kB. Planning Time 0.273 ms, Execution Time 0.465 ms.
--
--    Requirement: You may also use EXPLAIN ANALYZE to measure actual execution behavior.
--
--    Notes: EXPLAIN ANALYZE executes the SELECT, which is fine here since the statement doesn't
--    modify data.
--
--    Full EXPLAIN ANALYZE output from PostgreSQL:
--    Sort  (cost=36.48..36.98 rows=200 width=613) (actual time=0.377..0.384 rows=200.00 loops=1)
--      Sort Key: t.requested_at, t.trip_id
--      Sort Method: quicksort  Memory: 46kB
--      Buffers: shared hit=30
--      ->  Nested Loop  (cost=12.40..28.84 rows=200 width=613) (actual time=0.112..0.310 rows=200.00 loops=1)
--            Buffers: shared hit=30
--            ->  Hash Join  (cost=12.25..17.80 rows=200 width=314) (actual time=0.068..0.134 rows=200.00 loops=1)
--                  Hash Cond: (t.rider_id = r.rider_id)
--                  Buffers: shared hit=4
--                  ->  Seq Scan on trips t  (cost=0.00..5.00 rows=200 width=56) (actual time=0.029..0.052 rows=200.00 loops=1)
--                        Buffers: shared hit=3
--                  ->  Hash  (cost=11.00..11.00 rows=100 width=262) (actual time=0.027..0.028 rows=30.00 loops=1)
--                        Buckets: 1024  Batches: 1  Memory Usage: 10kB
--                        Buffers: shared hit=1
--                        ->  Seq Scan on riders r  (cost=0.00..11.00 rows=100 width=262) (actual time=0.012..0.015 rows=30.00 loops=1)
--                              Buffers: shared hit=1
--            ->  Memoize  (cost=0.15..0.41 rows=1 width=262) (actual time=0.000..0.000 rows=1.00 loops=200)
--                  Cache Key: t.driver_id
--                  Cache Mode: logical
--                  Hits: 187  Misses: 13  Evictions: 0  Overflows: 0  Memory Usage: 2kB
--                  Buffers: shared hit=26
--                  ->  Index Scan using drivers_pkey on drivers d  (cost=0.14..0.40 rows=1 width=262) (actual time=0.003..0.003 rows=1.00 loops=13)
--                        Index Cond: (driver_id = t.driver_id)
--                        Index Searches: 13
--                        Buffers: shared hit=26
--    Planning Time: 0.273 ms
--    Execution Time: 0.465 ms
--
EXPLAIN ANALYZE
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


-- B2: Which join algorithms did PostgreSQL choose?
--
--    Findings: Hash Join (trips to riders), then Nested Loop into drivers via Memoize and an Index
--    Scan on drivers_pkey. No Merge Join node.
--
--    Requirement: Identify the join algorithm or algorithms used, such as Nested Loop, Hash Join,
--    or Merge Join.
--
--    Notes: Memoize is a cache on the inner side of the nested loop, not a fourth join algorithm.
--

-- B3: Why would the planner pick those algorithms here?
--
--    Findings: Both joins are equalities. trips and riders are both read with a Seq Scan.
--    PostgreSQL hashes the small riders table (estimated 100, actual 30), although riders_pkey
--    could also support an indexed Nested Loop into riders.
--    drivers has drivers_pkey, so the nested loop fetches one driver per lookup; Memoize then skips
--    the index on a repeat driver_id (187 hits / 13 misses; the 13 misses match the 13 drivers who
--    actually have trips).
--
--    Requirement: Explain why PostgreSQL may have selected these algorithms, considering table
--    sizes and available indexes.
--
--    Notes: The course dataset defines primary-key and UNIQUE-constraint indexes, but no separate
--    indexes on trips.rider_id, trips.driver_id, or trips.requested_at. The rider scan estimated
--    100 rows but returned 30. Stale statistics are one possible explanation (not verified here);
--    ANALYZE could refresh the planner's estimates.
--

-- B4: Which part of this plan is the first to feel growth?
--
--    Findings: The Sort holds 200 rows in 46kB now; an unfiltered history of millions of trips
--    would sort a much larger result and could spill to disk. The Seq Scan on trips also grows with
--    every trip, since this report reads all of them. Memoize stays cheap only while a small number
--    of distinct drivers is shared across many trips.
--
--    Requirement: Predict which part of the query might become less efficient as the dataset grows.
--
--    Notes: 0.465 ms is one execution on this small load, not a number to quote as platform speed.
--    Indexes on the trip foreign keys would help a report filtered to a few drivers or riders more
--    than this one, which reads every trip.
--
