-- ============================================================================
-- Task 6.1 | Compute across a window without collapsing
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- Assignment 4 focus: review drivers 2 and 3; monitor driver 4.
--
-- Important: All trip statuses and $0 fares are included in the analysis.
-- This measures recorded fare per trip request, not just completed rides.
-- Cancelled trips that generate no recorded fare matter to platform financial
-- performance, especially given our focus on rider no-shows. Excluding them
-- would hide some of the impact of cancellations and make fares per request
-- look better than they are. However, $0 does not necessarily mean a rider
-- no-show, and recorded fares do not necessarily mean money was collected.
-- ============================================================================


-- -----------------------------------------------------------------------------
-- 1a: Which trips differ from their own driver's average recorded fare?
--
--    Findings: 200 rows, one per trip. Driver averages range from $11.94
--    (Driver 11) to $23.06 (Driver 5). Individual fares differ from their
--    driver's average by -$23.06 to +$51.37 (rounded to two decimals).
--    Trip 43 has the largest positive gap: $70.86 for Driver 4, whose
--    average is $19.49. All 34 cancelled trips have $0 recorded fares.
--    Drivers 14 and 15 do not appear because they have no recorded trips.
--
--    Requirement: "Compare each event to its producer’s average. Is an event unusual for its
--    own producer? Return every event with its producer’s average metric on the same row. Use
--    AVG(...) OVER (PARTITION BY ...). Then write the GROUP BY version and compare: how many
--    rows does each return, and what is lost?"
--
--    Notes: The window calculates the driver average without losing the
--    individual trip. diff_from_driver_avg is the fare minus that average.
--    Driver averages are not sorted by size: the first and last driver IDs
--    do not represent the minimum and maximum averages.
-- -----------------------------------------------------------------------------
SELECT
    driver_id,
    trip_id,
    fare_amount,
    ROUND(
        AVG(fare_amount) OVER (PARTITION BY driver_id),
        2
    )::NUMERIC(6,2) AS driver_avg_fare,
    ROUND(
        fare_amount - AVG(fare_amount) OVER (PARTITION BY driver_id),
        2
    )::NUMERIC(6,2) AS diff_from_driver_avg
FROM trips
ORDER BY driver_id, trip_id;


-- -----------------------------------------------------------------------------
-- 1b: What disappears when we report just one average per driver?
--
--    Findings: GROUP BY returns 13 rows versus 200 in 1a. Trip IDs,
--    individual fares, and their deviations from the averages disappear.
--
--    Requirement: "Compare each event to its producer’s average. Is an event unusual for its
--    own producer? Return every event with its producer’s average metric on the same row. Use
--    AVG(...) OVER (PARTITION BY ...). Then write the GROUP BY version and compare: how many
--    rows does each return, and what is lost?"
--
--    Notes: GROUP BY collapses trips into one row per driver, so we lose
--    individual trip IDs, fares, and deviations from the driver average.
--    I also ran the alternative CTE + JOIN version below for comparison.
--    It restored all 200 trip rows and the same driver averages, but did not
--    calculate diff_from_driver_avg. That expression could be added after the
--    JOIN; the window function in 1a is simply a more direct approach.
--
--    Alternative GROUP BY + JOIN version (executed for comparison):
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
    ROUND(AVG(fare_amount), 2)::NUMERIC(6,2) AS driver_avg_fare
FROM trips
GROUP BY driver_id
ORDER BY driver_id;


-- -----------------------------------------------------------------------------
-- 2: Who has the most trips, and how do three ranking methods handle ties?
--
--    Findings: 13 drivers have trips. Driver 6 ranks first with 21 trips;
--    Driver 4 ranks last with 6. Three tied pairs have 18 trips (5 and 7),
--    16 trips (2 and 11), or 11 trips (1 and 13). ROW_NUMBER() returns 13
--    unique positions. RANK() and DENSE_RANK() each have 10 distinct ranks;
--    RANK() ends at 13 because it leaves gaps, DENSE_RANK() ends at 10.
--
--    Requirement: "Rank producers three ways. Leadership wants to publish a producer
--    leaderboard. When two producers tie, the ranking method decides who appears higher. Rank
--    producers by number of events using ROW_NUMBER(), RANK(), and DENSE_RANK(), side by side
--    in one query. Make sure your output shows at least one tie."
--
--    Notes / tie-breaker decision:
--    * ROW_NUMBER() must give tied drivers different positions. I added
--      driver_id as a secondary ORDER BY key so those positions are stable
--      if the report is rerun against unchanged data. Without it, either
--      tied driver could get the lower row number; a final display ORDER BY
--      cannot make the window function's assignments deterministic.
--    * driver_id is only an arbitrary, reproducible display policy; it
--      does NOT show better performance or make a merit-based award fair.
--    * RANK() and DENSE_RANK() deliberately use ONLY trip count in their
--      window ORDER BY. Adding driver_id there would break genuine ties.
--      RANK() preserves ties and skips positions; DENSE_RANK() preserves
--      ties without gaps. A real bonus policy must explicitly handle ties.
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
        ORDER BY driver_total_trips DESC, driver_id
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
-- 3: Which trip-volume quartile is each driver in, and do ties cross bands?
--
--    Findings: NTILE(4) places 4 drivers in quartile 1 and 3 in each of
--    quartiles 2-4. Drivers 5 and 7 both have 18 trips but land in bands
--    1 and 2, respectively. Drivers 2 and 11 both have 16 trips but land
--    in bands 2 and 3. Drivers 1 and 13 (11 trips) share band 4.
--
--    Requirement: "Sort producers into four bands. Use NTILE(4) to split producers into four
--    groups by number of events. Look at what happens when tied producers land on both sides
--    of a group boundary."
--
--    Notes / tie-breaker decision:
--    * NTILE() divides row positions into similarly sized buckets, not
--      distinct trip-count values, so tied drivers may land in different
--      quartiles even after the tie-breaker is added.
--    * driver_id is a secondary ORDER BY key solely to keep assignments
--      reproducible. Without it, which tied driver gets the higher band
--      could vary between executions, even with unchanged trip counts.
--    * This is NOT a fairness fix: driver IDs are not performance measures.
--      For real rewards, stakeholders would need a policy that explicitly
--      addresses ties crossing a cutoff.
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
        ORDER BY driver_total_trips DESC, driver_id
    ) AS trip_number_quartile
FROM driver_trip_counts
ORDER BY trip_number_quartile, driver_total_trips DESC, driver_id;
