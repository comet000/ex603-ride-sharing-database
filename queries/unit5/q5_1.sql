-- ============================================================================
-- Task 5.1 | Connect Producers to Their Data
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- Assignment 4 focus: review drivers 2 and 3; monitor driver 4.
-- ============================================================================


-- -----------------------------------------------------------------------------
-- 1: Who was the rider and driver on each trip, and when was it requested?
--
--    Findings: 200 trips; 30 riders; 13 drivers. All 34 cancelled trips lack a completion time.
--
--    Requirement: "Who are the people behind the events? Write a query that joins three tables to
--    display the actor who performed each event, the producer associated with the event, and the
--    event's date and time."
--
--    Notes: JOIN keys are required in trips. COALESCE labels output only; it does not update stored
--    values.
-- -----------------------------------------------------------------------------
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


-- -----------------------------------------------------------------------------
-- 2a: Which badges are recorded for drivers 2, 3 and 4?
--
--    Findings: Eight awards across drivers 2, 3 and 4. None of the five badges is shared by all
--    three. Both drivers 2 and 3 hold Night Owl.
--
--    Requirement: "Do the producers identified in Assignment 4 share certain catalog credentials or
--    tags? Write a query that connects the producer table to the catalog table through the junction
--    table."
--
--    Notes: The junction table driver_badge_awards links drivers to badges and holds awarded_on.
-- -----------------------------------------------------------------------------
SELECT
    d.driver_id,
    d.driver_name,
    b.badge_name,
    a.awarded_on
FROM drivers d
    INNER JOIN driver_badge_awards a ON a.driver_id = d.driver_id
    INNER JOIN driver_badges b ON b.badge_id = a.badge_id
WHERE d.driver_id IN (2, 3, 4)
ORDER BY d.driver_id, b.badge_name;


-- -----------------------------------------------------------------------------
-- 2b: Which drivers hold the Night Owl badge?
--
--    Findings: Drivers 2, 3, 5, 10 and 11 hold Night Owl.
--
--    Requirement: "Return the producers associated with your theme's catalog tag."
--
--    Notes: Night Owl is the catalog tag examined here because it is shared by drivers 2 and 3.
--    Badge membership does not establish why riders did not show.
-- -----------------------------------------------------------------------------
SELECT
    d.driver_id,
    d.driver_name,
    b.badge_name,
    a.awarded_on
FROM drivers d
    INNER JOIN driver_badge_awards a ON a.driver_id = d.driver_id
    INNER JOIN driver_badges b ON b.badge_id = a.badge_id
WHERE b.badge_name = 'Night Owl'
ORDER BY d.driver_id;


-- -----------------------------------------------------------------------------
-- 3a: How do drivers 2, 3 and 4 compare with other drivers based in the same city?
--
--    Findings: Seven rows. Driver 2 has no Danang peer; driver 3 has two Haiphong peers; driver 4
--    has four Saigon peers.
--
--    Requirement: "How do the producers compare with one another? Write a self join to compare
--    records within the producer table. Use the results to explore whether the producers identified
--    in Assignment 4 share characteristics with other producers or whether differences in activity
--    levels may explain their performance."
--
--    Notes: LEFT JOIN retains driver 2 when no same-city peer exists. Driver 14 has zero trips,
--    so their no-show rate is NULL, not 0%. Home city is not the same as pickup city.
--    Using <> instead of < allows comparisons with peers who have lower driver IDs.
-- -----------------------------------------------------------------------------
WITH driver_activity AS (
    SELECT
        d.driver_id,
        COUNT(t.trip_id) AS trips,
        COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END)
            AS no_shows
    FROM drivers d
        LEFT JOIN trips t ON t.driver_id = d.driver_id
    GROUP BY d.driver_id
)
SELECT
    focus.driver_id AS focus_id,
    focus.driver_name AS focus_name,
    peer.driver_id AS peer_id,
    peer.driver_name AS peer_name,
    focus.home_city,
    fa.trips AS focus_trips,
    pa.trips AS peer_trips,
    fa.no_shows AS focus_no_shows,
    pa.no_shows AS peer_no_shows,
    ROUND(100.0 * fa.no_shows / NULLIF(fa.trips, 0), 2) AS focus_rate_pct,
    ROUND(100.0 * pa.no_shows / NULLIF(pa.trips, 0), 2) AS peer_rate_pct
FROM drivers focus
    LEFT JOIN drivers peer
        ON peer.home_city = focus.home_city
       AND peer.driver_id <> focus.driver_id
    INNER JOIN driver_activity fa ON fa.driver_id = focus.driver_id
    LEFT JOIN driver_activity pa ON pa.driver_id = peer.driver_id
WHERE focus.driver_id IN (2, 3, 4)
ORDER BY focus.driver_id, peer.driver_id;


-- -----------------------------------------------------------------------------
-- 3b: How do drivers 2, 3, and 4 compare with drivers who have a similar number of trips?
--
--    Findings: Driver 2: 18.75% vs peers 3.28% (4/122). Driver 3: 15.38% vs peers 5.77% (3/52).
--    Driver 4 has no qualifying peers, so its peer rate is NULL.
--
--    Requirement: "How do the producers compare with one another? Write a self join to compare
--    records within the producer table. Use the results to explore whether the producers identified
--    in Assignment 4 share characteristics with other producers or whether differences in activity
--    levels may explain their performance."
--
--    Notes: Peer range is +/-25% of trip count, chosen for exploration. Focus drivers 2, 3 and 4
--    are excluded from peer groups. Q3a self-joins drivers directly; Q3b self-joins
--    driver_stats, which summarizes activity by driver.
-- -----------------------------------------------------------------------------
WITH driver_stats AS (
    SELECT
        d.driver_id,
        d.driver_name,
        COUNT(t.trip_id) AS trips,
        COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END)
            AS no_shows
    FROM drivers d
        LEFT JOIN trips t ON t.driver_id = d.driver_id
    GROUP BY d.driver_id, d.driver_name
),
peer_totals AS (
    SELECT
        focus.driver_id AS focus_id,
        COUNT(peer.driver_id) AS peer_count,
        COALESCE(SUM(peer.trips), 0) AS peer_trips,
        COALESCE(SUM(peer.no_shows), 0) AS peer_no_shows
    FROM driver_stats focus
        LEFT JOIN driver_stats peer
            ON peer.driver_id <> focus.driver_id
           AND peer.driver_id NOT IN (2, 3, 4)
           AND peer.trips BETWEEN focus.trips * 0.75
                              AND focus.trips * 1.25
    WHERE focus.driver_id IN (2, 3, 4)
    GROUP BY focus.driver_id
)
SELECT
    focus.driver_id AS focus_id,
    focus.driver_name AS focus_name,
    focus.trips AS focus_trips,
    focus.no_shows AS focus_no_shows,
    ROUND(100.0 * focus.no_shows / NULLIF(focus.trips, 0), 2)
        AS focus_rate_pct,
    peer_totals.peer_count,
    peer_totals.peer_trips,
    peer_totals.peer_no_shows,
    ROUND(
        100.0 * peer_totals.peer_no_shows
        / NULLIF(peer_totals.peer_trips, 0),
        2
    ) AS peer_rate_pct
FROM driver_stats focus
    INNER JOIN peer_totals ON peer_totals.focus_id = focus.driver_id
WHERE focus.driver_id IN (2, 3, 4)
ORDER BY focus.driver_id;
