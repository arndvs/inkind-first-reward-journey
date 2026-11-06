# Gap register

Every gap in the journey, with the evidence that shows it, the impact, the fix, and the status. Evidence points to files in this repo. Status values: **Done** (fixed in the repo), **Open** (no change yet), **Decision** (waiting on an entry in [decisions.md](decisions.md)).

Priority: **P1** blocks launch or a business decision. **P2** should land before the next review. **P3** improves the record or the code's clarity.

## P1

| ID | Gap | Evidence | Impact | Fix | Status |
|---|---|---|---|---|---|
| G-01 | A saved restaurant can be added but never removed. | `rails/config/routes.rb` (`saved_restaurants` is `create` only); no `restaurant_unsaved` event. | Braze's `saved_restaurants` only grows; a message can name a place the user no longer wants. | Add an unsave route and a `restaurant_unsaved` event; rebuild the array in the payload; test both. | Done (D-03; tests in callbacks, payloads, console) |
| G-02 | A payment cannot be reversed, and a transaction does not link to its reward. | `rails/app/models/txn.rb`; no void route; `transactions` has no `reward_id`. | A refund leaves `first_transaction_at` set, which excludes the user from the audience. | Add a reversal record; clear `first_transaction_at` when the last non-reversed payment is gone; add a `reward_id` reference. | Open (D-04) |
| G-03 | The design assumes one referral reward per user. | `rails/db/schema.rb` (partial unique index on `rewards`); `docs/journey-spec.md` §4. | If a second reward is possible, the insert fails and the `first_reward_*` fields have nowhere to go. | Confirm the rule; if it is wrong, change the index and the view. | Decision (D-01) |
| G-04 | A save late in the week that does not convert has no follow-up after the Friday message. | `docs/journey-spec.md` §3. | The user's decision moment, a weekend evening, is outside the flow. | Choose option (a) or (b) in D-02 and update the Canvas and the flow. | Decision (D-02) |
| G-05 | The 4:30 PM local send depends on a time zone that the contract does not name. | No `time_zone` in `01-data-contract.md` §1. | Sends can land at the wrong hour. | Check whether Braze's time zone is populated (D-14). | Decision (D-14) |

## P2

| ID | Gap | Evidence | Impact | Fix | Status |
|---|---|---|---|---|---|
| G-06 | `search_performed` is listed in the contract but nothing produces it. | `01-data-contract.md` §1; no producer in `rails/`. | A documented signal that does not exist. | Marked **deferred** in `01-data-contract.md`. | Done (D-17) |
| G-07 | The contract promised batching of `/users/track`. | `01-data-contract.md` §5. | A reader would expect batched requests. | Sync rules now say what the validator enforces and that batching is not built. | Done (doc); enhancement open (D-18) |
| G-08 | Timing and audience rules exist only in the Braze UI. | `docs/journey-spec.md` §4 marks each as Designed. | Nothing in the repo proves the 4:30 PM, 3-day, Friday, 14-day, 30-day, or 10% rules are set. | Export or screenshot each Canvas step into a reviewed file, then check the values against §4. | Open |
| G-09 | The push has no destination in the repo. | `03-message.liquid`; `liquid/messages/first_reward.push.liquid`. | The push's tap target is set in Braze's composer and is not reviewable. | Write the deep link into `docs/journey-spec.md` §5 and into the push template. | Open |
| G-10 | The saved email has no trust element. | `liquid/blocks/sections/` (no testimonial, press, or partner block). | Lower confidence for a first-time reader. | Add one partner or review line, or record why it is omitted. | Open |
| G-11 | Users cannot change or remove what they create. | Same as G-01 and G-02; the operator console has no update or destroy route. | Corrections need a developer. | Saved restaurants done (G-01); transactions still open (G-02); add an operator correction path. | Partly done |
| G-12 | The operator console is built but is not labelled as internal in the design record. | `rails/app/views/users/`; `rails/config/routes.rb`. | A reader could take it for a product screen. | Labelled as internal in `docs/journey-spec.md` §5. | Done |
| G-13 | Customer validation has not run. | No session notes or recordings in the repo. | The design is tested only for correctness, not for whether people want it. | Run the plan in [customer-validation.md](customer-validation.md). | Open |
| G-14 | The attribute list is short and has no demographic fields. | `docs/journey-spec.md` §6. | Targeting depends on guesses about the audience. | Add V1 and later flags (done in §6); list demographic candidates with a source each. | Partly done |
| G-15 | Canvas settings are not exported. | No Canvas file in the repo. | The journey cannot be reviewed from version control. | Export each Canvas and store it outside version control, with a link in `verification.md`. | Open |
| G-20 | A Canvas does not exit when a saved restaurant is removed. | `docs/journey-spec.md` section 3 | The Canvas keeps its delay running. The message no longer names the removed restaurant, but the user can still receive the nudge. | Add an exit on `restaurant_unsaved` for the same restaurant, using Braze's event-property filter, and record it in the Canvas export (G-15). | Open |
| G-21 | Each attribute list is built when its job first runs, not when its event happened. | `rails/app/jobs/braze/track_job.rb` (`create_delivery`); `rails/app/lib/braze/payloads.rb` (`saved_restaurant_keys`) | A later job rebuilds the list from the database, so the last list delivered is current. But a job that runs late can send a list that already includes a later change, which its own event does not describe. | Store the list on the event when the event is written, and build the payload from that snapshot. | Open |
| G-22 | A queued job for a record removed before it ran raised `RecordNotFound`. | `Braze::TrackJob#perform` | A quick save-then-remove crashed a queued job. | `locate` returns nil and the job returns without sending. Test: `rails/test/jobs/braze/track_job_test.rb`. | Done |
| G-23 | The CI gem audit failed on Rails 8.1.4 and two HTML sanitizers. | `bin/bundler-audit` (advisories for actionpack, actionmailbox, actionview, activestorage, activesupport, loofah, rails-html-sanitizer) | CI failed at the Gem audit step before this change. | Patch-level update within `~> 8.1.4` (decision D-26). `bin/ci` passes. | Done |

## P3

| ID | Gap | Evidence | Impact | Fix | Status |
|---|---|---|---|---|---|
| G-16 | The Rails test count in older notes was estimated. | Earlier notes said "about 137 test blocks" from a grep. | The number in any document could be wrong. | Run `bin/rails test` and record the count in `verification.md`. | Open |
| G-17 | The generic email has no mobile screenshot. | `liquid/previews/screenshots/`. | Mobile layout unchecked for that version. | Generate the screenshot with the existing `build_previews.py --screenshots`. | Open |
| G-18 | The Liquid test count was estimated in older notes. | Earlier notes said "about 175". | Same as G-16. | Verified: 180 tests pass (see `verification.md`). | Done |
| G-19 | A stale link to `docs/images/` in a temporary file. | `rails/tmp/pr-video.md`. | Ignored by git (`rails/.gitignore`); no effect on the repo. | None needed. | Done (not tracked) |

## Summary

- P1 (5): 1 done (G-01); 1 open (G-02); 3 waiting on decisions (G-03 with D-01, G-04 with D-02, G-05 with D-14).
- P2 (14): 5 done (G-06, G-07 doc, G-12, G-22, G-23); 7 open (G-08, G-09, G-10, G-13, G-15, G-20, G-21); 2 partly done (G-11, G-14).
- P3 (4): 2 open (G-16, G-17); 2 done (G-18, G-19).
