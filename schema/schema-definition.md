# Schema Definition

**Theme:** Ride Sharing Database

This is the schema for a ride-sharing platform. Main tables are riders, drivers, trips, the badges drivers can earn, and the awards table that links drivers to badges.

### 1. riders (Actor)

| Attribute     | Domain       | Key         |
|---------------|--------------|-------------|
| rider_id      | BIGINT       | Primary Key |
| display_name  | VARCHAR(100) | —           |

rider_id is just the unique ID for each rider.  
display_name is whatever name shows up to other people on the platform.

### 2. drivers (Producer)

| Attribute     | Domain       | Key         |
|---------------|--------------|-------------|
| driver_id     | BIGINT       | Primary Key |
| display_name  | VARCHAR(100) | —           |
| is_active     | BOOLEAN      | —           |
| rating        | NUMERIC(2,1) | —           |

driver_id uniquely identifies each driver.  
display_name is the public name.  
is_active tracks if the driver is currently accepting trips.  
rating sits on the driver record so it can be used for filtering and ranking without having to recalculate it every time.

### 3. trips (Event)

| Attribute       | Domain        | Key                             |
|-----------------|---------------|---------------------------------|
| trip_id         | BIGINT        | Primary Key                     |
| rider_id        | BIGINT        | Foreign Key → riders.rider_id   |
| driver_id       | BIGINT        | Foreign Key → drivers.driver_id |
| trip_timestamp  | TIMESTAMPTZ   | —                               |
| fare_amount     | NUMERIC(10,2) | —                               |

Each trip has its own trip_id.  
It always links to one rider and one driver.  
trip_timestamp is when the trip took place. fare_amount is the dollar amount we’ll use later for totals and averages.

### 4. driver_badges (Catalog)

| Attribute | Domain       | Key         |
|-----------|--------------|-------------|
| badge_id  | BIGINT       | Primary Key |
| name      | VARCHAR(100) | —           |

badge_id is the primary key.  
name is the actual title of the badge.

### 5. driver_badge_awards (Junction)

| Attribute   | Domain      | Key                                               |
|-------------|-------------|---------------------------------------------------|
| driver_id   | BIGINT      | Primary Key, Foreign Key → drivers.driver_id      |
| badge_id    | BIGINT      | Primary Key, Foreign Key → driver_badges.badge_id |
| awarded_at  | TIMESTAMPTZ | —                                                 |

Composite key on (driver_id, badge_id) stops the same badge being given to the same driver more than once.  
I added awarded_at so we can see when badges were earned instead of only which ones exist.

### Relationship Summary

- A rider can have zero or many trips. Every trip belongs to exactly one rider.
- A driver can have zero or many trips. Every trip is tied to one driver.
- Drivers can collect multiple badges over time.
- A single badge can be awarded to many different drivers.
- driver_badge_awards is the table that connects them and also stores when the award happened.
