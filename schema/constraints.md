# Integrity Constraints

These constraints are meant to stop invalid or inconsistent data from getting into the database. The names match `schema.sql`.

## Primary Keys

- `pk_riders`: riders.rider_id
- `pk_drivers`: drivers.driver_id
- `pk_trips`: trips.trip_id
- `pk_driver_badges`: driver_badges.badge_id
- `pk_driver_badge_awards`: composite (driver_id, badge_id). That stops the same badge from being given to the same driver more than once.

## NOT NULL Constraints

These columns need values for a record to make sense:

- riders: display_name, email, phone_number, joined_date
- drivers: display_name, email, phone_number, license_number, joined_date, is_active
- trips: rider_id, driver_id, trip_time_requested, trip_time_start, trip_time_end, trip_distance_miles, fare_amount, tip_amount
- driver_badges: name
- driver_badge_awards: driver_id, badge_id, awarded_at

Trips are completed rides only, which is why the start, end, distance and fare columns are all required. A request that was cancelled before the ride happened isn't stored in this table.

Some columns are nullable on purpose:

- **drivers.rating** is NULL until the driver has been rated. A brand new driver has no trips yet, so there's nothing to average.
- **trips.trip_rating** is NULL if the rider never rated the trip.

Defaults: joined_date defaults to today, is_active to TRUE, tip_amount to 0, and awarded_at to the current timestamp.

## CHECK Constraints

- `chk_drivers_rating_range`: drivers.rating between 0 and 5.
- `chk_trips_rating_range`: trips.trip_rating between 0 and 5.
- `chk_trips_start_after_request`: trip_time_start >= trip_time_requested.
- `chk_trips_end_after_start`: trip_time_end >= trip_time_start.
- `chk_trips_distance_nonnegative`: trip_distance_miles >= 0.
- `chk_trips_fare_nonnegative`: fare_amount >= 0.
- `chk_trips_tip_nonnegative`: tip_amount >= 0.

These just stop obviously bad values (like a 9.9 rating, a negative fare, or a trip that ends before it starts) from being stored. The rating checks let NULL through, so unrated drivers and trips are still fine.

## UNIQUE Constraints

- `uq_riders_email` and `uq_drivers_email`: no two riders share an email, and no two drivers share one.
- `uq_drivers_license_number`: two drivers can't have the same license number.
- `uq_driver_badges_name`: there's no good reason to have two different badges with the exact same name.

Email is only unique within its own table. Someone who both rides and drives can have the same email in both, which is one of the costs of not having a shared accounts table (see the note on this in `analysis/unit2.md`).

## Foreign Keys and ON DELETE Behavior

All four foreign keys use **ON DELETE RESTRICT**.

| Foreign key | ON DELETE | Reason |
|---|---|---|
| `fk_trips_rider`: trips.rider_id → riders.rider_id | RESTRICT | A rider's trips are historical fare records and shouldn't disappear when the account does. |
| `fk_trips_driver`: trips.driver_id → drivers.driver_id | RESTRICT | Deleting a driver shouldn't wipe out their trip history. |
| `fk_awards_driver`: driver_badge_awards.driver_id → drivers.driver_id | RESTRICT | Awards are a record of what a driver earned. |
| `fk_awards_badge`: driver_badge_awards.badge_id → driver_badges.badge_id | RESTRICT | A badge shouldn't be deletable while awards still point to it. |

The rule is the same everywhere: trips and awards are history, so they're protected. The is_active flag is the proper way to "remove" a driver. If someone asks for their data to be deleted, the plan is to anonymize their personal fields and keep the row, not hard-delete it. More on that in `analysis/unit2.md`.

## Indexes

Postgres doesn't index foreign key columns on its own, so I added `idx_trips_rider_id`, `idx_trips_driver_id` and `idx_awards_badge_id`. I also added `idx_trips_time_start` for date-range questions. The composite key on awards already handles lookups by driver.

## Summary

The constraints are designed to keep the data clean and to protect historical trip and award records from being accidentally wiped out by cascading deletes.
