-- =================================================================
-- EX 603 Assignment 2 — schema.sql
-- Theme: Ride Sharing
-- Target: PostgreSQL 14+
--
-- =================================================================
-- Creation order (table -> tables it points at):
--   1. riders                 -> (nothing)
--   2. drivers                -> (nothing)
--   3. driver_badges          -> (nothing)
--   4. trips                  -> riders, drivers
--   5. driver_badge_awards    -> drivers, driver_badges
--
-- Run it with: psql -d ridesharing -f schema/schema.sql
-- =================================================================

-- Reset. Reverse creation order, so no dependency blocks a drop.
DROP TABLE IF EXISTS driver_badge_awards CASCADE;
DROP TABLE IF EXISTS trips               CASCADE;
DROP TABLE IF EXISTS driver_badges       CASCADE;
DROP TABLE IF EXISTS drivers             CASCADE;
DROP TABLE IF EXISTS riders              CASCADE;

-- ----------------------------------------------------------------
-- 1. riders (actor) — goes first, points at nothing.
--    email is UNIQUE but not the key, because people change emails.
--    phone_number is required. Drivers and riders have to be able to
--    reach each other for pickups, so a rider with no number is no use.
-- ----------------------------------------------------------------
CREATE TABLE riders (
    rider_id     INTEGER GENERATED ALWAYS AS IDENTITY,
    display_name VARCHAR(100) NOT NULL,
    email        VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20)  NOT NULL,
    joined_date  DATE         NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_riders PRIMARY KEY (rider_id),
    CONSTRAINT uq_riders_email UNIQUE (email)
);

-- ----------------------------------------------------------------
-- 2. drivers (producer) — also points at nothing.
--    rating is NULL until the driver gets their first rated trip
--    (NULL = "not rated yet"). CHECK lets NULL through, so the 0-5
--    range only kicks in for real ratings.
--
--    Heads up: rating is the ONE deliberately stored derived value
--    in this schema. It's a copy of AVG(trips.trip_rating) for that
--    driver, kept here so we can filter and rank drivers without
--    averaging every trip every time. A GENERATED ... STORED column
--    can't do it (those can only look at their own row, not other
--    tables), so the app has to keep it fresh. That's the price of
--    denormalizing. Everything else derived (trip duration, trip
--    counts, fare totals) is computed at query time instead.
-- ----------------------------------------------------------------
CREATE TABLE drivers (
    driver_id      INTEGER GENERATED ALWAYS AS IDENTITY,
    display_name   VARCHAR(100) NOT NULL,
    email          VARCHAR(255) NOT NULL,
    phone_number   VARCHAR(20)  NOT NULL,
    license_number VARCHAR(30)  NOT NULL,
    joined_date    DATE         NOT NULL DEFAULT CURRENT_DATE,
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    rating         NUMERIC(3,2),
    CONSTRAINT pk_drivers PRIMARY KEY (driver_id),
    CONSTRAINT uq_drivers_email UNIQUE (email),
    CONSTRAINT uq_drivers_license_number UNIQUE (license_number),
    CONSTRAINT chk_drivers_rating_range
        CHECK (rating BETWEEN 0 AND 5)
);

-- ----------------------------------------------------------------
-- 3. driver_badges (catalog) — points at nothing.
-- ----------------------------------------------------------------
CREATE TABLE driver_badges (
    badge_id INTEGER GENERATED ALWAYS AS IDENTITY,
    name     VARCHAR(100) NOT NULL,
    CONSTRAINT pk_driver_badges PRIMARY KEY (badge_id),
    CONSTRAINT uq_driver_badges_name UNIQUE (name)
);

-- ----------------------------------------------------------------
-- 4. trips (event) — has to come after riders and drivers.
--    RESTRICT on both FKs: trips are history, so a rider or driver
--    who has trips can't be hard-deleted.
--
--    This table only holds trips that actually happened (completed
--    rides), which is why the start, end, distance and fare columns
--    are all NOT NULL. A cancelled request has no home here.
--
--    Trip duration is NOT stored. It's trip_time_end minus
--    trip_time_start, worked out at query time.
--    trip_distance_miles is the real distance, filled in when the
--    trip finishes (not the estimate from before the ride).
--    trip_rating is the rider's rating; NULL if they skipped it.
-- ----------------------------------------------------------------
CREATE TABLE trips (
    trip_id             INTEGER GENERATED ALWAYS AS IDENTITY,
    rider_id            INTEGER       NOT NULL,
    driver_id           INTEGER       NOT NULL,
    trip_time_requested TIMESTAMP     NOT NULL,
    trip_time_start     TIMESTAMP     NOT NULL,
    trip_time_end       TIMESTAMP     NOT NULL,
    trip_distance_miles NUMERIC(6,2)  NOT NULL,
    fare_amount         NUMERIC(10,2) NOT NULL,
    tip_amount          NUMERIC(10,2) NOT NULL DEFAULT 0,
    trip_rating         NUMERIC(3,2),
    CONSTRAINT pk_trips PRIMARY KEY (trip_id),
    CONSTRAINT fk_trips_rider
        FOREIGN KEY (rider_id) REFERENCES riders (rider_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_trips_driver
        FOREIGN KEY (driver_id) REFERENCES drivers (driver_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_trips_start_after_request
        CHECK (trip_time_start >= trip_time_requested),
    CONSTRAINT chk_trips_end_after_start
        CHECK (trip_time_end >= trip_time_start),
    CONSTRAINT chk_trips_distance_nonnegative
        CHECK (trip_distance_miles >= 0),
    CONSTRAINT chk_trips_fare_nonnegative
        CHECK (fare_amount >= 0),
    CONSTRAINT chk_trips_tip_nonnegative
        CHECK (tip_amount >= 0),
    CONSTRAINT chk_trips_rating_range
        CHECK (trip_rating BETWEEN 0 AND 5)
);

-- ----------------------------------------------------------------
-- 5. driver_badge_awards (junction) — last, since it needs both
--    drivers and driver_badges to exist. The primary key is the
--    pair of foreign keys (no new id), so a driver can't get the
--    same badge twice. awarded_at lives here because "when" belongs
--    to the pairing, not to the driver or the badge on their own.
-- ----------------------------------------------------------------
CREATE TABLE driver_badge_awards (
    driver_id  INTEGER   NOT NULL,
    badge_id   INTEGER   NOT NULL,
    awarded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_driver_badge_awards PRIMARY KEY (driver_id, badge_id),
    CONSTRAINT fk_awards_driver
        FOREIGN KEY (driver_id) REFERENCES drivers (driver_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_awards_badge
        FOREIGN KEY (badge_id) REFERENCES driver_badges (badge_id)
        ON DELETE RESTRICT
);

-- ----------------------------------------------------------------
-- Indexes. Postgres indexes primary keys and UNIQUE columns on its
-- own, but NOT foreign key columns, so I added those by hand.
-- The composite PK on awards already covers driver-first lookups,
-- so only badge_id needs its own index there.
-- trip_time_start gets one for date-range questions.
-- ----------------------------------------------------------------
CREATE INDEX idx_trips_rider_id   ON trips (rider_id);
CREATE INDEX idx_trips_driver_id  ON trips (driver_id);
CREATE INDEX idx_trips_time_start ON trips (trip_time_start);
CREATE INDEX idx_awards_badge_id  ON driver_badge_awards (badge_id);
