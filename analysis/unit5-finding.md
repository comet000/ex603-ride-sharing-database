# assignment 5 Finding: Drivers With No-Shows and Drivers With No Trips Need Different Follow-ups

**To:** Leadership team  
**From:** Trust and Data team

**Bottom line:** Our corrected rider no-show rate is still **12 out of 200 trips (6.0%)**, as we established in assignments 3 and 4. Joining the records now gives us two very different groups to follow up with: **drivers 2 and 3**, whose trips have unusually high recorded no-show rates, and **drivers 14 and 15**, who have **no recorded trips at all**. They shouldn't go on the same problem list or get the same response.

## The drivers whose trips had more no-shows

I'd still start with **driver 2 (Driver_02)**, who has **three rider no-shows in 16 trips (18.75%)**, followed by **driver 3 (Driver_03)**, with **two in 13 (15.38%)**. Their rates are also higher than those of other drivers with roughly similar trip counts. That makes the individual trips worth reviewing, but it doesn't tell us that either driver did something wrong. **A rider no-show is recorded against a trip, not proof the driver caused it.**

Driver Operations and Rider Support should pull up those five trips and look for the pieces missing from our current data: whether the driver reached the pickup, how long they waited, whether either side tried to make contact, and whether the reason was entered correctly. We also know from assignment 4 that driver ratings weren't a convincing explanation, and the new badge comparison doesn't settle it either. Drivers 2 and 3 both earned **Night Owl**, but three other drivers have that badge too. **Driver 4 (Driver_04)** should stay on the watch list rather than get the same investigation: its **16.67%** rate is just **one no-show in six trips**.

## The drivers who have no recorded trips

**Driver 14 (Driver_14)** and **driver 15 (Driver_15)** need an **onboarding or account-status check**, not a no-show review. Both were onboarded in **2022** and are still marked **active**, yet neither has a single trip in the **2023 records**. An INNER JOIN had been leaving them out of our driver activity reports entirely. We now know they have no trips in this dataset; we **don't** know that they never drove or why no trips appear.

Driver Operations should check whether their accounts were fully set up, whether they were eligible to receive trip offers, and whether they received any. Trust and Data should check for missing history or stale account information, including where their stored ratings came from. If they're trying to drive but something is blocking them, fix the problem. If they've stopped participating, update their status. Don't label them poor performers just because the event table is empty.

## What I'd do with the findings

Keep the dashboard and any bonus decisions tied to the **correct 6.0% rider no-show definition**, not the old "about half" number that caused the payout problem in assignment 3. For drivers **2 and 3**, review the **events** and collect more context before deciding whether anything needs to change. For drivers **14 and 15**, verify the **accounts and missing activity**. Those are separate jobs for the operations team, and neither calls for an automatic penalty.

The main improvement this assignment isn't a new alarming percentage. It's that we can see **who is behind the recorded trips and who was missing from the report altogether**—which gives leadership a much better starting point for the right follow-up.
