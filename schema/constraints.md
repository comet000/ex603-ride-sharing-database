# Integrity Constraints

These constraints are meant to stop invalid or inconsistent data from getting into the database.

## Primary Keys

- riders.rider_id is the primary key (unique and not null).
- drivers.driver_id is the primary key (unique and not null).
- trips.trip_id is the primary key (unique and not null).
- driver_badges.badge_id is the primary key (unique and not null).
- driver_badge_awards uses a composite primary key on (driver_id, badge_id). That stops the same badge from being given to the same driver more than once.

## NOT NULL Constraints

These columns need values for a record to make sense:

- riders.display_name
- drivers.display_name
- drivers.is_active
- drivers.rating
- trips.rider_id
- trips.driver_id
- trips.trip_timestamp
- trips.fare_amount
- driver_badges.name
- driver_badge_awards.driver_id
- driver_badge_awards.badge_id
- driver_badge_awards.awarded_at

Primary key columns are already NOT NULL by definition.

## CHECK Constraints

- drivers.rating must be between 0 and 5 (inclusive).
- trips.fare_amount must be greater than or equal to 0.

These just stop obviously bad values (like a 9.9 rating or a negative fare) from being stored.

## UNIQUE Constraints

- driver_badges.name should be unique. There’s no good reason to have two different badges with the exact same name.

## Foreign Keys and ON DELETE Behavior

### trips.rider_id → riders.rider_id  
**ON DELETE RESTRICT**  

You shouldn’t be able to delete a rider if they still have trips on record. Trips are historical data and shouldn’t disappear just because the rider account is removed.

### trips.driver_id → drivers.driver_id  
**ON DELETE RESTRICT**  

Same idea for drivers. Deleting a driver should not wipe out their trip history.

### driver_badge_awards.driver_id → drivers.driver_id  
**ON DELETE RESTRICT**  

If a driver has earned badges, those award records should stay even if the driver is later removed.

### driver_badge_awards.badge_id → driver_badges.badge_id  
**ON DELETE RESTRICT**  

A badge shouldn’t be deletable while any awards still point to it. This keeps the history of who earned what intact.

I used RESTRICT on all four foreign keys on purpose. The consistent rule is that historical records (trips and awards) are protected. In practice this means hard-deletes of riders or drivers almost never happen once they have activity. The is_active flag is the proper way to “remove” someone instead.

## Summary

The constraints are designed to keep the data clean and to protect historical trip and award records from being accidentally wiped out by cascading deletes.
