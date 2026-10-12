-- ============================================================
-- Task 3.1: Establish what the data contains
-- Theme: RideSharing   Database: ex603_data
-- ============================================================

-- 3.1 Setup check: did the dataset load? Row count for every table.
--    Showed 30 riders, 15 drivers, 23 languages, 5 driver badges, 25 badge awards, and 200 trips.
SELECT
  (SELECT COUNT(*) FROM riders)              AS riders,
  (SELECT COUNT(*) FROM drivers)             AS drivers,
  (SELECT COUNT(*) FROM driver_languages)    AS driver_languages,
  (SELECT COUNT(*) FROM driver_badges)       AS driver_badges,
  (SELECT COUNT(*) FROM driver_badge_awards) AS driver_badge_awards,
  (SELECT COUNT(*) FROM trips)               AS trips;


-- 3.1a Active, highly rated drivers with a minimum rating of 4.5.
--    There are 5 drivers that meet these criteria.
--    Requirement: SELECT, WHERE, ORDER BY, LIMIT.
SELECT
  driver_id,
  driver_name,
  avg_rating
FROM drivers
WHERE is_active = TRUE
  AND avg_rating >= 4.5
ORDER BY avg_rating DESC
LIMIT 10;


-- 3.1b-1 All possible trip statuses.
--    Requirement: SELECT DISTINCT.
--    Showed three values: disputed, completed and cancelled.
--    'disputed' is a value I did not expect.
SELECT DISTINCT trip_status
FROM trips;


-- 3.1b-2 All possible cancellation reasons for each type of trip status.
--    Requirement: SELECT DISTINCT over two columns.
--    Trips with a cancelled status have 4 possible cancellation reasons, including 'Rider no show.'
--    Completed and disputed trips have no recorded reason (NULL).
SELECT DISTINCT
  trip_status,
  cancellation_reason
FROM trips
ORDER BY trip_status, cancellation_reason;


-- 3.1c-1 Trips with a fare of $5 or less.
--    Requirement: Filter a numeric range.
--    Showed 37 rows. All trips with a cancelled status (34 trips) had a fare amount of 0.
SELECT
  trip_id,
  driver_id,
  trip_status,
  cancellation_reason,
  fare_amount
FROM trips
WHERE fare_amount BETWEEN 0 AND 5
ORDER BY cancellation_reason DESC, fare_amount DESC;


-- 3.1c-2 Every trip that was not completed. (cancelled or disputed only).
--    Requirement: Filter using an explicit list of values with IN.
--    Showed 44 rows.
SELECT
  trip_id,
  driver_id,
  trip_status,
  cancellation_reason
FROM trips
WHERE trip_status IN ('cancelled', 'disputed')
ORDER BY trip_id;


-- 3.1d-1 Drivers whose name ends in 1.
--    Requirement: Match a text pattern using LIKE.
--    Showed 2 rows, Driver_01 and Driver_11.
SELECT
  driver_id,
  driver_name
FROM drivers
WHERE driver_name LIKE '%1'
ORDER BY driver_id;


-- 3.1d-2 Trips with no recorded cancellation reason.
--    Requirement: Identify records where a reason/value is missing (NULL), COALESCE to replace.
--    Showed 166 rows, all of them completed or disputed trips.
SELECT
  trip_id,
  trip_status,
  COALESCE(cancellation_reason, 'No reason provided') AS reason_label
FROM trips
WHERE cancellation_reason IS NULL
ORDER BY trip_id;


-- 3.1d-3 All cancelled trips without a recorded reason.
--    Requirement: IS NULL.
--    Showed 0 rows. No cancelled trip has a NULL reason.
SELECT
  trip_id,
  trip_status
FROM trips
WHERE trip_status = 'cancelled'
  AND cancellation_reason IS NULL;


-- 3.1e-1 Percentage of all trips that were completed, cancelled, or disputed.
--    Requirement: Calculated columns and CASE.
--    Showed 78% of trips were successfully completed, 17% were cancelled, and 5% were disputed.
SELECT
    CASE trip_status
        WHEN 'completed' THEN 'Successfully completed'
        WHEN 'cancelled' THEN 'Trip cancelled'
        WHEN 'disputed' THEN 'Trip disputed'
        ELSE 'Other outcome'
    END AS trip_outcome,
    COUNT(*) AS number_of_trips,
    ROUND(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM trips),
        1
    ) AS percentage_of_all_trips
FROM trips
GROUP BY trip_status
ORDER BY number_of_trips DESC;

-- 3.1e-2 Percentage of all trips that were rider no-shows.
--    Requirement: Calculated columns.
--    Showed 12 of 200 trips were rider no-shows, which is 6.0%.
--    The dashboard reported about half.
SELECT
    (SELECT COUNT(*) FROM trips) AS total_trips,
    (SELECT COUNT(*)
     FROM trips
     WHERE cancellation_reason = 'Rider no show') AS rider_no_shows,
    ROUND(
        100.0 * (SELECT COUNT(*)
                 FROM trips
                 WHERE cancellation_reason = 'Rider no show')
              / (SELECT COUNT(*) FROM trips),
        1
    ) AS rider_no_show_pct;
