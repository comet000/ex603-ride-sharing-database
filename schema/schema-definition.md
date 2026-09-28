# Schema Definition

**Theme:** Ride Sharing Database

This is the schema for a ride-sharing platform. The main tables are riders, drivers, trips, the badges drivers can earn, and the awards table that links drivers to badges. The types match the PostgreSQL version in `schema.sql`.

### 1. riders (Actor)

| Attribute    | Domain                                | Key         |
|--------------|---------------------------------------|-------------|
| rider_id     | INTEGER GENERATED ALWAYS AS IDENTITY  | Primary Key |
| display_name | VARCHAR(100), NOT NULL                | —           |
| email        | VARCHAR(255), NOT NULL, UNIQUE        | —           |
| phone_number | VARCHAR(20), NOT NULL                 | —           |
| joined_date  | DATE, NOT NULL, DEFAULT CURRENT_DATE  | —           |

rider_id is just the unique ID for each rider.
display_name is whatever name shows up to other people on the platform.
email is unique but it isn't the key, because people change their emails.
phone_number is required, since drivers and riders need to be able to reach each other for pickups.
joined_date is the day the rider signed up.

### 2. drivers (Producer)

| Attribute      | Domain                                | Key         |
|----------------|---------------------------------------|-------------|
| driver_id      | INTEGER GENERATED ALWAYS AS IDENTITY  | Primary Key |
| display_name   | VARCHAR(100), NOT NULL                | —           |
| email          | VARCHAR(255), NOT NULL, UNIQUE        | —           |
| phone_number   | VARCHAR(20), NOT NULL                 | —           |
| license_number | VARCHAR(30), NOT NULL, UNIQUE         | —           |
| joined_date    | DATE, NOT NULL, DEFAULT CURRENT_DATE  | —           |
| is_active      | BOOLEAN, NOT NULL, DEFAULT TRUE       | —           |
| rating         | NUMERIC(3,2), nullable                | —           |

driver_id uniquely identifies each driver.
display_name is the public name.
license_number is the driver's license, and no two drivers can share one.
is_active tracks if the driver is currently accepting trips. It's also how you "remove" a driver without deleting them.
rating is the one value in this schema that's stored even though it could be worked out. It's basically the average of that driver's trip ratings, kept on the driver row so it can be used for filtering and ranking without recalculating every time. It stays NULL until the driver has been rated once, and the application is responsible for keeping it up to date.

### 3. trips (Event)

| Attribute           | Domain                                 | Key                             |
|---------------------|----------------------------------------|---------------------------------|
| trip_id             | INTEGER GENERATED ALWAYS AS IDENTITY   | Primary Key                     |
| rider_id            | INTEGER, NOT NULL                      | Foreign Key → riders.rider_id   |
| driver_id           | INTEGER, NOT NULL                      | Foreign Key → drivers.driver_id |
| trip_time_requested | TIMESTAMP, NOT NULL                    | —                               |
| trip_time_start     | TIMESTAMP, NOT NULL                    | —                               |
| trip_time_end       | TIMESTAMP, NOT NULL                    | —                               |
| trip_distance_miles | NUMERIC(6,2), NOT NULL                 | —                               |
| fare_amount         | NUMERIC(10,2), NOT NULL                | —                               |
| tip_amount          | NUMERIC(10,2), NOT NULL, DEFAULT 0     | —                               |
| trip_rating         | NUMERIC(3,2), nullable                 | —                               |

Each trip has its own trip_id. It always links to one rider and one driver. This table only holds trips that actually happened, so a cancelled request isn't a row here.
trip_time_requested is when the rider asked for the ride, trip_time_start is when the trip actually began, and trip_time_end is when it finished.
trip_distance_miles is the real distance, recorded when the trip is done. It's not the estimate from before the trip.
fare_amount is the dollar amount we'll use later for totals and averages, and tip_amount is any tip on top of that.
trip_rating is how the rider rated the trip. It's empty if they never rated it.

**Derived, not stored:** trip duration. It's just trip_time_end minus trip_time_start, so I calculate it at query time.

### 4. driver_badges (Catalog)

| Attribute | Domain                               | Key         |
|-----------|--------------------------------------|-------------|
| badge_id  | INTEGER GENERATED ALWAYS AS IDENTITY | Primary Key |
| name      | VARCHAR(100), NOT NULL, UNIQUE       | —           |

badge_id is the primary key.
name is the actual title of the badge.

### 5. driver_badge_awards (Junction)

| Attribute  | Domain                                         | Key                                               |
|------------|------------------------------------------------|---------------------------------------------------|
| driver_id  | INTEGER, NOT NULL                              | Primary Key, Foreign Key → drivers.driver_id      |
| badge_id   | INTEGER, NOT NULL                              | Primary Key, Foreign Key → driver_badges.badge_id |
| awarded_at | TIMESTAMP, NOT NULL, DEFAULT CURRENT_TIMESTAMP | —                                                 |

Composite key on (driver_id, badge_id) stops the same badge being given to the same driver more than once.
awarded_at lives here and not on driver_badges, because when a badge was earned is about one driver getting one badge, not about the badge itself.

### Relationship Summary

- A rider can have zero or many trips. Every trip belongs to exactly one rider.
- A driver can have zero or many trips. Every trip is tied to exactly one driver.
- Drivers can collect multiple badges over time.
- A single badge can be awarded to many different drivers.
- driver_badge_awards is the table that connects them and also stores when the award happened.
