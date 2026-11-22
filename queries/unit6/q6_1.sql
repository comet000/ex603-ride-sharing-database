-- ============================================================================
-- Task 6.1 | Compute across a window without collapsing
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- Assignment 4 focus: review drivers 2 and 3; monitor driver 4.
--
-- Important: All trip statuses and $0 fares are included in the analysis.
-- This allows us to measure recorded fare per trip request and count all
-- trip activity, rather than only completed rides.
-- Cancelled trips that generate no fare are relevant to the platform's
-- financial performance, especially given our focus on rider no-shows.
-- Excluding them would hide the financial impact of these cancellations
-- and potentially make performance appear better than it is.
-- However, $0 fares do not necessarily indicate rider no-shows, and
-- recorded fares do not necessarily represent revenue ultimately collected.
-- ============================================================================


-- -----------------------------------------------------------------------------
-- 1a: Which trips differ from their driver’s average fare amount?
--
--    Findings: 200 rows returned.
--    All individual fares differ from their driver's average fare amount.
--    The average fare of each driver ranges from 16.03 to 19.86.
--    Individual fares differ from their driver's average by -23.06 to +51.37.
--
--    Requirement: "Compare each event to its producer’s average. Is an event unusual for its
--    own producer? Return every event with its producer’s average metric on the same row. Use
--    AVG(...) OVER (PARTITION BY ...). Then write the GROUP BY version and compare: how many
--    rows does each return, and what is lost?"
--
--    Notes: The window function preserves individual trip records.
--    AVG() OVER (PARTITION BY driver_id) calculates each driver's
--    average without collapsing those records.
--    diff_from_driver_avg measures each trip's deviation from that average.
--
-- ----------------------------------------------------------------------------
SELECT
    driver_id,
    trip_id,
    fare_amount,
    ROUND(
        AVG(fare_amount) OVER
            (PARTITION BY driver_id
    )::numeric, 2) AS driver_avg_fare,
    ROUND(
        (fare_amount - AVG(fare_amount) OVER
            (PARTITION BY driver_id)
    )::numeric, 2) AS diff_from_driver_avg
FROM trips
ORDER BY driver_id, trip_id;


-- -----------------------------------------------------------------------------
-- 1b: What disappears when we report just one average per driver?
--
--    Findings: This query produced 13 rows, compared with 200 in 1a.
--    GROUP BY returns one average per driver, losing individual trip IDs, fare amounts, and
--    the ability to identify which trips differ from their driver's average.
--
--    Requirement: "Compare each event to its producer’s average. Is an event unusual for its
--    own producer? Return every event with its producer’s average metric on the same row. Use
--    AVG(...) OVER (PARTITION BY ...). Then write the GROUP BY version and compare: how many
--    rows does each return, and what is lost?"
--
--    Notes: GROUP BY collapses trips into one row per driver, losing
--    individual trip IDs and fare amounts. In an alternate version, I joined
--    the grouped averages back to trips, which restored all 200 rows and
--    produced the same results as 1a. Both approaches work, but the window
--    function preserves trip-level detail directly without a CTE and JOIN.
--    Alt version:
--
--     WITH driver_avg_fares AS (
--         SELECT
--             driver_id,
--             ROUND(AVG(fare_amount)::numeric, 2) AS driver_avg_fare
--         FROM trips
--         GROUP BY driver_id
--     )
--     SELECT
--         t.driver_id,
--         t.trip_id,
--         t.fare_amount,
--         d.driver_avg_fare
--     FROM trips t
--     JOIN driver_avg_fares d
--         ON t.driver_id = d.driver_id
--     ORDER BY t.driver_id, t.trip_id;
--
-- -----------------------------------------------------------------------------
SELECT
    driver_id,
    ROUND(AVG(fare_amount)::numeric, 2) AS driver_avg_fare
FROM trips
GROUP BY driver_id
ORDER BY driver_id;

-- -----------------------------------------------------------------------------
-- 2: Who has the most trips, and how do different rankings handle ties?
--
--    Findings: Driver 6 ranks first across all three methods, with 21 trips.
--    Driver 4 universally ranks last, with 6 trips.
--    ROW_NUMBER() assigns 13 unique positions, while RANK() and DENSE_RANK()
--    each identify 10 distinct ranks, including three pairs of tied drivers.
--    With RANK(), drivers 5 & 7 tie for 4th, 2 & 11 for 7th, and 1 & 13 for 11th.
--    With DENSE_RANK(), those pairs rank 4th, 6th, and 9th, respectively.
--    RANK() reaches position 13 because of gaps, while DENSE_RANK() ends at 10.
--
--    Requirement: "Rank producers three ways. Leadership wants to publish a producer
--    leaderboard. When two producers tie, the ranking method decides who appears higher. Rank
--    producers by number of events using ROW_NUMBER(), RANK(), and DENSE_RANK(), side by side
--    in one query. Make sure your output shows at least one tie."
--
--    Notes: ROW_NUMBER() assigns unique positions even when trip counts tie,
--    but without a tie-breaker, the order of tied drivers is not guaranteed.
--    RANK() gives tied drivers the same rank, leaving gaps in the ranking sequence.
--    DENSE_RANK() also preserves ties, but without gaps.
--
-- -----------------------------------------------------------------------------
WITH driver_trip_counts AS (
    SELECT
        driver_id,
        COUNT(*) AS driver_total_trips
    FROM trips
    GROUP BY driver_id
)
SELECT
    driver_id,
    driver_total_trips,
    ROW_NUMBER() OVER (
        ORDER BY driver_total_trips DESC
    ) AS row_num,
    RANK() OVER (
        ORDER BY driver_total_trips DESC
    ) AS driver_rank,
    DENSE_RANK() OVER (
        ORDER BY driver_total_trips DESC
    ) AS driver_dense_rank
FROM driver_trip_counts
ORDER BY driver_total_trips DESC, driver_id;


-- -----------------------------------------------------------------------------
-- 3: Which trip-volume band is each driver in, and do ties cross bands?
--
--    Findings: Of 13 drivers, quartile 1 contains 4, while quartiles 2-4 contain 3 each.
--    Two pairs of tied drivers fall on opposite sides of a group boundary.
--    Drivers 5 and 7, each with 18 trips, fall into quartiles 1 and 2, respectively.
--    Drivers 2 and 11, each with 16 trips, fall into quartiles 2 and 3, respectively.
--    Drivers 1 and 13, each with 11 trips, both fall into quartile 4.
--
--    Requirement: "Sort producers into four bands. Use NTILE(4) to split producers into four
--    groups by number of events. Look at what happens when tied producers land on both sides
--    of a group boundary."
--
--    Notes: NTILE(4) divides drivers into roughly equal-sized groups, regardless of ties.
--    Without a tie-breaker (like driver_id), which tied driver falls into which quartile
--    is not guaranteed.
--
-- -----------------------------------------------------------------------------
WITH driver_trip_counts AS (
    SELECT
        driver_id,
        COUNT(*) AS driver_total_trips
    FROM trips
    GROUP BY driver_id
)
SELECT
    driver_id,
    driver_total_trips,
    NTILE(4) OVER (
        ORDER BY driver_total_trips DESC
    ) AS trip_number_quartile
FROM driver_trip_counts
ORDER BY trip_number_quartile, driver_total_trips DESC;
