-- ============================================================================
-- Task 5.1 | Connect Producers to Their Data
-- Theme: Ride Sharing   Database: ex603_data   Source: rideshare.sql
-- Failure = cancellation_reason = 'Rider no show' (Assignments 3 and 4).
-- Assignment 4 focus: investigate drivers 2 and 3; monitor driver 4,
-- whose observed no-show rate is based on only 6 trips.
-- ============================================================================

-- 5.1 Q1 | Question: Who were the riders and drivers involved in each trip,
--                    when did it occur, and what was its outcome?
-- Findings: All 200 trips match one rider and one driver; 30 distinct riders
--           and 13 distinct drivers appear. The requests span 2023-01-01
--           through 2023-12-28. All 34 NULL completion times belong to
--           cancelled trips.
-- Notes: COALESCE replaces missing report values without changing the data.
--        TO_CHAR converts completed_at to TEXT for the 'Not completed' label;
--        requested_at remains a timestamp and is used for sorting.
-- Requirement: "Who are the people behind the events? Write a query that joins
--               three tables to display the actor who performed each event,
--               the producer associated with the event, and the event's date
--               and time."
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


-- 5.1 Q2a | Question: Which catalog badges have drivers 2, 3, and 4 earned?
-- Findings: Eight badge awards: driver 2 has Airport Pro, Night Owl, and
--           Safe Driving; driver 3 has Clean Car and Night Owl; driver 4
--           has Clean Car, Five Star, and Safe Driving. No badge is held
--           by all three drivers.
-- Notes: The junction table driver_badge_awards connects drivers to badges.
-- Requirement: "Do the producers identified in Assignment 4 share certain
--               catalog credentials or tags? Write a query that connects the
--               producer table to the catalog table through the junction
--               table. Return the producers associated with your theme's
--               catalog tag."
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


-- 5.1 Q2b | Question: Which drivers have earned the 'Night Owl' badge?
-- Findings: Five holders: drivers 2, 3, 5, 10, and 11. Both priority
--           drivers (2 and 3) have this badge; that does not establish
--           a cause of rider no-shows.
-- Requirement: "Do the producers identified in Assignment 4 share certain
--               catalog credentials or tags? Write a query that connects the
--               producer table to the catalog table through the junction
--               table. Return the producers associated with your theme's
--               catalog tag."
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


-- 5.1 Q3a | Question: How do the Assignment 4 drivers compare with drivers
--                     based in the same HOME city?
-- Findings: Seven rows, including driver 2 with no same-city peer (NULL).
--           Driver 3: 13 trips, 2 no-shows (15.38%); Haiphong peers are
--           driver 6 (21 trips, 1 no-show, 4.76%) and driver 11
--           (16 trips, 1 no-show, 6.25%).
--           Driver 4: 6 trips, 1 no-show (16.67%); Saigon peers are drivers
--           5 (18 trips, 0), 7 (18 trips, 1), 8 (20 trips, 0), and
--           14 (0 trips, 0). Driver 14's zero trips differ from driver 2's
--           lack of any matching peer.
-- Notes: The self-join is drivers focus LEFT JOIN drivers peer. The LEFT
--        JOIN retains driver 2, who is the only driver based in Danang.
--        Home city does not necessarily indicate where trips were picked up.
--        NULLIF avoids dividing by zero for a peer with zero trips.
-- Requirement: "How do the producers compare with one another? Write a self
--               join to compare records within the producer table. Use the
--               results to explore whether the producers identified in
--               Assignment 4 share characteristics with other producers or
--               whether differences in activity levels may explain their
--               performance."
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
    peer.driver_id AS peer_id,
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


-- 5.1 Q3b | Question: Do drivers 2, 3, and 4 have higher observed no-show
--                     rates than non-flagged drivers with similar trip volume?
-- Findings: Driver 2: 3/16 = 18.75%; 7 peers: 4/122 = 3.28%.
--           Driver 3: 2/13 = 15.38%; 4 peers: 3/52 = 5.77%.
--           Driver 4: 1/6 = 16.67%; no peers in the defined range,
--           so its peer rate is NULL, not 0%.
-- Notes: This supplementary comparison self-joins the per-driver statistics
--        in driver_stats; Q3a above self-joins the producer table itself.
--        "Similar volume" means within +/-25% of the focus driver's trips.
--        This is an exploratory cutoff, not a statistical standard. Drivers
--        2, 3, and 4 are excluded from one another's comparison groups.
--        The peer groups overlap, and low event counts limit conclusions.
-- Requirement: "How do the producers compare with one another? Write a self
--               join to compare records within the producer table. Use the
--               results to explore whether the producers identified in
--               Assignment 4 share characteristics with other producers or
--               whether differences in activity levels may explain their
--               performance."
WITH driver_stats AS (
    SELECT
        d.driver_id,
        COUNT(t.trip_id) AS trips,
        COUNT(CASE WHEN t.cancellation_reason = 'Rider no show' THEN 1 END)
            AS no_shows
    FROM drivers d
        LEFT JOIN trips t ON t.driver_id = d.driver_id
    GROUP BY d.driver_id
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
    focus.trips AS focus_trips,
    focus.no_shows AS focus_no_shows,
    ROUND(100.0 * focus.no_shows / NULLIF(focus.trips, 0), 2)
        AS focus_rate_pct,
    peer_totals.peer_count,
    peer_totals.peer_trips,
    peer_totals.peer_no_shows,
    ROUND(
        100.0 * peer_totals.peer_no_shows
        / NULLIF(peer_totals.peer_trips, 0), 2
    ) AS peer_rate_pct
FROM driver_stats focus
    INNER JOIN peer_totals ON peer_totals.focus_id = focus.driver_id
WHERE focus.driver_id IN (2, 3, 4)
ORDER BY focus.driver_id;
