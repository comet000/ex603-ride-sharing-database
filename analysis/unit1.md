# Unit 1 Analysis

## Modeling Justification

I designed the database around the five required roles: riders, drivers, trips, driver_badges, and driver_badge_awards. Each table has a clear job. Riders and drivers can exist on their own (a new rider or driver doesn’t need any trips yet), while every trip must point to exactly one rider and one driver.

I used BIGINT surrogate keys for the main entities. Names are not reliable primary keys because two people can share the same display name, and names can change. A simple numeric ID gives each record a stable, unique identity and keeps the foreign-key relationships clean and simple. The trips table also gets its own trip_id because each trip is a distinct event that may need to be referenced on its own.

For the many-to-many relationship between drivers and badges I used a junction table with a composite primary key on (driver_id, badge_id). That combination already uniquely identifies the relationship and automatically stops the same badge being awarded to the same driver twice. I also added an awarded_at column because the relationship itself carries useful information. Knowing *when* a badge was earned is valuable for later analysis, so it belongs in the database rather than being left out.

I chose ON DELETE RESTRICT for all four foreign keys. Trips and badge awards are historical facts. Deleting a rider, driver, or badge should not silently erase that history. RESTRICT forces an explicit decision before any of those records can disappear. The is_active flag on drivers already gives a practical way to take a driver offline without destroying their past trips or awards. In practice this means hard deletes of riders or drivers will be rare once they have any activity, which matches how most real platforms actually behave.

I put the basic integrity rules in the schema itself: primary keys, foreign keys, required columns, the 0–5 range on rating, non-negative fares, and unique badge names. These rules should hold no matter which application or process writes the data. I left more flexible business logic to the application. For example, how a driver’s rating is calculated or recalculated after each trip, or the exact conditions under which a driver becomes inactive. Those rules are more likely to change over time and I don’t think they need to be hard-coded into the table definitions.

Overall the design keeps stable entities (riders, drivers, badges) separate from high-volume event data (trips) and from the many-to-many awards relationship. This should support both day-to-day operations (recording trips, awarding badges) and the analytical queries that come later (trip counts, fare totals, driver performance, badge trends).

## Reflection

One decision a different designer could reasonably have made differently is the primary key on the driver_badge_awards table. Instead of the composite key (driver_id, badge_id) I could have given the table its own surrogate award_id.

I stuck with the composite key because the main purpose of the table is simply to record the relationship between a driver and a badge. The two foreign keys already identify that relationship uniquely, and they automatically prevent duplicate awards. In terms of how the platform will actually use the data, awards will mostly be inserted and then looked up by driver or by badge (for example “which badges has this driver earned?” or “who has this specific badge?”). They are unlikely to be referenced individually by lots of other tables. Adding an extra award_id would have made the model slightly more complex without giving much practical benefit for the expected read and write patterns. The composite key therefore felt like the simpler and more natural choice.
