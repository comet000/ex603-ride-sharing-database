# Unit 2 Analysis: From Diagram to Database

## Changes from Unit 1

Building the schema (and taking a second look at my diagram while I did it) led to a few updates to my Unit 1 design. I brought the ERD, `schema-definition.md`, `constraints.md` and the README in line with all of them.

- **Key type:** My Unit 1 diagram used BIGINT keys. The DDL uses `INTEGER GENERATED ALWAYS AS IDENTITY`, which is what the course type mapping asks for. Foreign key columns are INTEGER too, since a foreign key has to match the type it points at exactly.
- **Rating:** `drivers.rating` went from `NUMERIC(2,1)` to `NUMERIC(3,2)` (the course type for ratings) and is now nullable. In Unit 1 I made it NOT NULL, but a brand new driver has no trips and so no rating to show. NULL means "not rated yet", and the 0 to 5 CHECK still applies to any real value.
- **Timestamps:** `TIMESTAMPTZ` became `TIMESTAMP` to follow the course mapping.
- **Extra columns:** riders and drivers got `email`, `phone_number` and `joined_date`, drivers got `license_number`, and trips got `trip_time_requested`, `trip_time_start`, `trip_time_end`, `trip_distance_miles`, `tip_amount` and `trip_rating`. The old single `trip_timestamp` was split into request, start and end times.
- **New constraints:** the new columns came with new rules. Unit 1 only had two CHECKs (driver rating range and non-negative fare) and one UNIQUE (badge name). There are now seven CHECKs, plus UNIQUE on both emails and on the license number. They're all covered below.
- **Defaults:** `is_active` defaults to TRUE, `tip_amount` to 0, and `awarded_at` to the current timestamp.
- **Indexes:** I added foreign key indexes, because Postgres doesn't make them automatically.
- **Phone numbers are required:** `phone_number` is NOT NULL on both riders and drivers. On a ride-sharing platform a driver and a rider have to be able to reach each other at pickup, so a row with no number isn't useful.
- **Relationship labels:** My Unit 1 diagram labeled the rider and driver lines "has" and "drives", and the badge line "defines". "Has" works in both directions (a rider has trips, but a trip also has a rider), and "defines" is an odd fit for badges and awards. I reworded them so each label only makes sense one way. Riders *request* trips, drivers *accept* trips, and badges are *awarded in* the awards table. "Earns" for drivers and awards stays the same.

## Derived values: stored or computed?

The course says a derived value can be a stored generated column or just computed at query time, as long as I say which one I picked and why. So here's the full list.

- **Trip duration:** computed at query time (`trip_time_end - trip_time_start`). It's cheap to work out and storing it would just give it a chance to disagree with the two timestamps it comes from.
- **Trip counts, fare totals, badge counts:** computed at query time, same reasoning.
- **drivers.rating:** this one is stored, and I want to be upfront that it's a deliberate denormalization. It's basically the average of that driver's `trip_rating` values. The course structure wants the producer to carry a numeric attribute that can be filtered and ranked on, and averaging every trip for every driver each time you want a leaderboard would get old fast on a big trips table. A `GENERATED ALWAYS AS (...) STORED` column can't do it, because generated columns can only look at their own row and not at other tables. So the application has to recalculate it, and the cost is that if some code path forgets, the number goes stale. The CHECK only guarantees it's in range, not that it's *right*. I'm okay with that trade for this project, and if I ever wanted to be safe about it I could add a nightly job that compares it to the real average.

I also don't have a recursive foreign key. The ERD doesn't have any relationship where a table points back at itself, and I didn't want to invent something like `referred_by` just to have one.

## Foreign keys and ON DELETE

| Foreign key | ON DELETE | Reason |
|---|---|---|
| `trips.rider_id` → `riders` | RESTRICT | A rider's trips are historical fare records and shouldn't vanish or get orphaned. |
| `trips.driver_id` → `drivers` | RESTRICT | A driver's trips feed earnings and performance history, so they have to be kept. |
| `driver_badge_awards.driver_id` → `drivers` | RESTRICT | Awards are a record of what a driver earned and shouldn't quietly disappear. |
| `driver_badge_awards.badge_id` → `driver_badges` | RESTRICT | A badge that's in use can't be removed from the catalog without someone deciding what happens to its awards. |

### What each choice governs

**A rider deleting their account (`trips.rider_id`).** This is a totally routine thing to happen. With RESTRICT, the delete just fails as long as the rider has any trips. The people who'd feel it otherwise are the drivers and whoever does finance, since their fare history includes those trips. With CASCADE, every trip that rider ever took would be deleted, and driver earnings and platform revenue totals would quietly shrink with no error anywhere. With SET NULL, the trips would lose their rider, which would mean making the column nullable and giving up the rule that every trip has a rider. So RESTRICT it is. The route for a departing rider is to keep the row and blank out their personal info (see the data deletion section below).

**A driver leaving the platform (`trips.driver_id`, `awards.driver_id`).** This is the situation `is_active` was made for. Setting `is_active = FALSE` takes them offline and keeps their history. RESTRICT stops anyone from hard-deleting a driver who has trips or awards. Under CASCADE, deleting a driver would wipe out their completed trips, which riders may still need for receipts and disputes, plus all their badges. A driver with no activity (like a mistaken sign-up) can still be deleted, because RESTRICT only blocks the delete when child rows exist. I'll admit `awards.driver_id` is the one I could see going CASCADE, since an award means nothing without its driver. I kept it RESTRICT anyway so all four keys follow the same simple rule, and because a driver who has awards almost certainly has trips too, so RESTRICT would already be blocking them.

**Retiring a badge (`awards.badge_id`).** Say the platform stops offering something like "Driver of the Month". Deleting it would either fail (RESTRICT) or, under CASCADE, wipe every award of it. The drivers who earned it are the ones affected, since they'd lose recognition they actually earned, and any "badge trends" analysis would lose its history. RESTRICT forces someone to make a deliberate call about those awards first.

The common thread is that trips and awards are facts about the past, so deleting a parent should never rewrite them.

### What if someone asks for their data to be deleted?

This is a real tension in my design. RESTRICT means I literally can't hard-delete a rider or driver who has any trip history, and that clashes with a "right to be forgotten" style request. I'm not building a technical solution for this now, but here's the plan: anonymize instead of delete. Keep the row and its trips so the foreign keys and the fare history stay intact, and overwrite the personal fields.

Since `email`, `phone_number` and `license_number` are all NOT NULL (and email and license number are UNIQUE too), you can't just set them to NULL. They get placeholders instead. Email and license number need to stay unique, so they get something built from the id, like `'deleted-' || rider_id || '@invalid.example'`, and `phone_number` (which isn't unique) can just be set to `'DELETED'`. I tried this on a test row and it works fine with all the constraints in place. The people affected are the person asking (they get their data scrubbed) and finance and drivers (their history stays whole). Under CASCADE the deletion would be "cleaner" but it would corrupt everyone else's records, which is a worse trade.

## CHECK constraints

I've got seven, and I tested each one against a bad insert to make sure it actually fires.

**`chk_drivers_rating_range` (`rating BETWEEN 0 AND 5`).** Makes a driver rating above 5 or below 0 unstorable. The column type alone doesn't stop this, since `NUMERIC(3,2)` happily holds up to 9.99. A bad value could come from a bug in the code that recalculates the average, a slipped digit like 8.5 instead of 4.5, or a bulk import from a system that uses a 0 to 10 scale. (Anything bigger than 9.99, like a 45, gets rejected by the column type itself, so the CHECK is really there for the values in between.) A bad rating would mess up driver rankings and any filter like "rated 4.5 or higher". NULL passes the check, so unrated new drivers are still allowed.

**`chk_trips_rating_range` (`trip_rating BETWEEN 0 AND 5`).** Same idea, but for the rating a rider gives a trip. It matters even more here, because these are the raw values the driver average gets built from, so one bad 9.5 would drag a driver's whole average up. It could come from the same places: a client bug, a slipped digit, or an import on a 0 to 10 scale. NULL is still fine for trips nobody rated.

**`chk_trips_start_after_request` (`trip_time_start >= trip_time_requested`).** Makes it impossible for a trip to start before it was requested. That could happen from a clock mix-up between the rider's phone and the server, or from someone editing one timestamp and forgetting the other. If it got through, wait-time calculations would come out negative.

**`chk_trips_end_after_start` (`trip_time_end >= trip_time_start`).** Makes a trip that ends before it starts unstorable. Same causes as above, plus swapped columns in an import. Since duration is computed as end minus start, a violation would produce a negative duration, and that would quietly wreck average trip length and anything per-minute. I used `>=` and not `>` so a trip that starts and ends in the same instant (a driver ending it by mistake, say) doesn't get rejected.

**`chk_trips_distance_nonnegative` (`trip_distance_miles >= 0`).** No negative distances. It could come from a sign error, or a GPS or odometer glitch where the end reading is lower than the start. Negative miles would pull down distance averages and any fare-per-mile number. Zero is allowed on purpose, since a trip that ends right where it started (a rider changing their mind after getting in) is odd but still real.

**`chk_trips_fare_nonnegative` (`fare_amount >= 0`).** Makes a negative fare unstorable. It could come from a sign error in the fare calculation, or from someone recording a refund or discount by inserting a negative trip instead of using a proper mechanism. A negative fare would quietly lower `SUM(fare_amount)` and `AVG(fare_amount)`, which are the numbers revenue reporting relies on. Zero is deliberately allowed since a fully discounted or free ride is valid.

**`chk_trips_tip_nonnegative` (`tip_amount >= 0`).** Same reasoning as fare. A negative tip could come from a bug or from someone trying to record a tip refund as a negative row, and it would make driver earnings look lower than they are. Zero is the default and is valid, since most trips probably don't get tipped.

## Other constraints worth noting

- `uq_driver_badges_name` stops two catalog badges from having the same name, which would make "who has this badge?" ambiguous.
- `uq_riders_email`, `uq_drivers_email` and `uq_drivers_license_number` stop duplicate accounts and two drivers claiming the same license.
- **Trips are completed trips only.** `trip_time_start`, `trip_time_end`, `trip_distance_miles` and `fare_amount` are all NOT NULL, and so is `driver_id`, which means a request that got cancelled before a driver picked it up or before the ride began has nowhere to live in this table. That's on purpose. The distance is "recorded when the trip is done" and the duration comes from start and end, so every row is a ride that actually happened. Storing cancellations would mean making those columns nullable, adding a status column, and writing CHECKs so a "completed" trip still can't have a missing end time. That's a bigger design, and I'd rather keep the trips table clean and simple than half-support it.
- The composite primary key `pk_driver_badge_awards` stops the same badge going to the same driver twice. The trade-off is that a repeatable badge (like a monthly one) would need a different design, probably a surrogate award id.
- NOT NULL is on every column that has to have a value for the row to make sense. The only deliberate exceptions are `drivers.rating` and `trips.trip_rating`, which stay empty until someone has actually been rated.

## Why riders and drivers are separate tables

In a production system I would almost certainly introduce a shared accounts table and make riders and drivers subtypes of it, the same is-A pattern from the Music Streaming lesson. That would hold the shared stuff (email, phone, joined date) in one place and support single sign-on for someone who both rides and drives. For this project I kept them as independent tables so the schema stays lined up with the required five-role structure and the actor/producer/event layout the course uses.

A different designer could reasonably have gone the other way, and I don't think separate tables are a bad answer on their own. They keep the write path for high-frequency trip requests simple, they avoid a bunch of NULLs, and they keep driver operational status (`is_active`) away from rider profiles. The cost is that someone who both rides and drives ends up with two rows, with the same email and phone stored twice and nothing in the schema knowing they're the same person.

## Things the schema doesn't catch

Because riders and drivers are separate tables, nothing stops a trip where the rider and the driver are the same real person, if that person has an account in both tables. That's another cost of not having a shared accounts table. I'd handle it in the application for now.
