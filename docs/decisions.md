# Decisions

Each decision that changes behaviour, scope, or data, with its status and the reason. Accepted decisions can be reversed only by adding a new entry that supersedes them. Open decisions need an answer from the owner named in the entry.

Status values: **Accepted** (in force), **Open** (answer needed), **Deferred** (intentionally not now), **Proposed** (recommended, not yet agreed).

## Open

| ID | Question | Options | Recommendation | Owner | Blocks |
|---|---|---|---|---|---|
| D-01 | Can a user hold more than one referral welcome reward? | (a) No: keep the one-per-user index and document it. (b) Yes: change the index, reshape `first_reward_*` into per-reward records, update the view. | Confirm with the business before launch. The index makes (b) a schema change, so answer it before the first Braze import. | Product | Launch |
| D-02 | What reaches a user whose save happens late in the week and who does not buy before the Friday follow-up? | (a) A Saturday-evening follow-up for users who saved at least five days earlier and have not bought. (b) A re-entry on a browse session 14 days after the save, which the 30-day cap limits. | (a): it is one more Braze step, and it lands on the weekend decision moment the case describes. | Product | Canvas design |
| D-05 | Is a first meal under the minimum counted as a conversion? | (a) Yes, it ends the journey, and the reward stays unused. (b) No, it does not exit the journey. | (a), and send a separate reminder about the unused reward. | Product | Metrics |
| D-13 | What is the exact name of the total-sessions filter in Braze? | Confirm in the Braze filter picker. | Confirm before building Canvas B. | Operator | Canvas B |
| D-14 | Where does each user's time zone come from? | (a) Braze's user time zone, if populated from the SDK. (b) A time zone attribute the backend sends. | Check (a) in the Braze workspace. Use (b) only if (a) is empty. | Operator | 4:30 PM local send |

## Accepted

| ID | Decision | Reason | Where it lives |
|---|---|---|---|
| D-03 | A saved restaurant must be removable. | Without removal, the Braze array only grows and a message can name a place the user no longer wants. | Built: `DELETE /users/:id/saved_restaurants/:id`; see `docs/journey-spec.md` section 2. |
| D-04 | A transaction is reversed by a reversal record, not by deleting the row. | A payment is financial history; a reversal keeps the trail and lets the warehouse clear `first_transaction_at` on the next sync. | Not built: see G-02. |
| D-21 | Each delivery is built once and stored; retries resend the stored payload. | A rebuilt payload could differ from the one already sent, and a retry could double-count. | `rails/app/jobs/braze/track_job.rb` |
| D-06 | The default mode is `record`. Nothing in this repo calls Braze. | No live send has been approved. The Braze trial covers rendering only. | `rails/app/lib/braze/client.rb` |
| D-07 | `saved_restaurants` stores restaurant keys, not names. | Keys stay stable when a name changes; the message reads the current name from the Catalog. | `rails/app/lib/braze/payloads.rb` |
| D-08 | One system owns each profile field. | Two writers race, and the profile keeps whichever arrived last. | `docs/journey-spec.md` §4 |
| D-09 | Two Canvases: one on saves, one on browsing without saves. | Entry filters apply to every trigger in a Canvas, so a session filter on the save Canvas would also block savers. | `docs/journey-spec.md` §3 |
| D-10 | The nearby call is not retried. | With a retry, Braze aborts the message after repeated failures instead of falling back to the Explore copy. | `liquid/blocks/logic/ik_get_nearby.liquid` |
| D-11 | The copy always states the minimum, and a missing minimum aborts the send. | Copy that hides the minimum sets up a disappointment at checkout. | `03-message.liquid` |
| D-12 | The reward is checked for presence before it is compared. | Comparing a missing value in Liquid can error; the abort stops rendering at once. | `03-message.liquid` |
| D-15 | Each event key is deterministic, and events are append-only. | Event records are the audit trail for what happened; a deterministic key stops a re-run from duplicating them. | `rails/app/models/app_event.rb` |
| D-16 | The warehouse export writes `exported_at` only after a successful MERGE. | A failed export must be retried, not skipped. | `rails/app/lib/warehouse/export.rb` |
| D-22 | A removal is recorded as a `restaurant_unsaved` event, not only as a deleted row. | After `destroy`, a track job cannot locate the removed `SavedRestaurant` by its GlobalID. The event is what Braze can be sent from, and it keeps the history. | `rails/app/models/saved_restaurant.rb`, `rails/app/models/app_event.rb` |
| D-23 | A queued job whose record was removed returns without sending. | The removal's own event carries the current list, so nothing is lost. Retrying a missing record would fail on every attempt. | `rails/app/jobs/braze/track_job.rb` |
| D-24 | Deleting a user or restaurant writes no `restaurant_unsaved` event. | A cascade is not a user action, and an event for a record being deleted cannot be sent. `destroyed_by_association` makes the rule explicit, instead of depending on the order of the associations. | `rails/app/models/saved_restaurant.rb` |
| D-25 | A Canvas context restaurant is featured only while the profile lists it, or when the profile has no list. | A removed save must not be named after its removal. With no list, the context is the only signal, so it is kept. This is the one intended change to Liquid output. | `liquid/blocks/logic/ik_get_saved_restaurant.liquid`, `03-message.liquid` |
| D-26 | Patch-level Rails and sanitizer gems are updated within `~> 8.1.4`. | The audit found advisories against 8.1.4, and the fixes are patch releases. The constraint and the code are unchanged. | `rails/Gemfile.lock` |

## Deferred

| ID | Item | Reason | Revisit when |
|---|---|---|---|
| D-17 | `search_performed` event | No producer exists. Adding one needs a search surface in the app. | The app emits search events. |
| D-18 | Batching `/users/track` requests | Volume is one object per action in this version; the 75-object limit is enforced. | Volume approaches Braze's rate limits. |
| D-19 | Operator authentication on the console | The console runs locally with fictional data. | Before the console is reachable outside a developer machine. |
| D-20 | Reconcile job and saved-restaurant backfill | Needed before a real launch, not for the proof of concept. | Before production data is loaded. |
