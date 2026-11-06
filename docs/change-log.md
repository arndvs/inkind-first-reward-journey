# Change log

Each change is recorded with the process stage that found it, the failing test for each step, what the tests caught, and what was left open. Older passes are in the [verification record](verification.md).

---

## 2026-11-06: remove a saved restaurant

### Why this change

The stage 2 check (every entity that can be created must also be changeable and removable) found that a saved restaurant could be added and never removed. The gap was in the Braze profile too: `saved_restaurants` could only grow, so a message could keep naming a place the user had given up. It was recorded as G-01 and decision D-03 before any code changed.

### Process trace

| Stage | What happened |
|---|---|
| 1. Problem | Unchanged. The pain statement already covers a restaurant the user wants to keep or drop. |
| 2. Entities | The CRUD check failed for saved restaurants. A removal needs an event, a payload, and a route. |
| 3. Flow | Added the removal to the journey: a removal sends the remaining list, and a removed restaurant is not named later. |
| 4. Attributes | `saved_restaurants` must match the database after a removal. The payload already reads the current rows, so it needed no new attribute. |
| 5. Screen contract | Each saved restaurant gets one Remove action. It returns to the user page with a notice. |
| 6. Build | Model, then payload, then delivery, then route and controller, then the view. One slice at a time, each starting with a failing test. |
| 7. Validate | The tests and a walk of the flow found three problems the design had not covered (below). Targeted tests ran after each slice; the full CI run passed at the end. |
| 8. Ship | Not done. A live send needs the Canvas exit on removal (G-20) first. |

### Red and green, slice by slice

Each red step was run and checked for the expected failure before the green change.

| Slice | Red test | Red failure | Green change |
|---|---|---|---|
| Model writes the event | `callbacks_test`: removing a saved restaurant writes one `restaurant_unsaved` event and one track job | `1 jobs expected, but 0 were enqueued` | `after_destroy` writes the event; `AppEvent` enqueues for `TRACKED_EVENTS` |
| Removal and event commit together | `callbacks_test`: the two are written together or not at all | Passed on the first run | None. The guard stays: the callback runs inside the destroy transaction |
| Deleting a user writes no event | `callbacks_test`: deleting a user sends no unsave | Passed on the first run | Refactor: `unless: :destroyed_by_association` makes the rule explicit instead of depending on association order |
| Payload | `payloads_test`: `restaurant_unsaved` carries the remaining keys | `NoMethodError: undefined method 'restaurant_unsaved'` | Builder added; refactor extracted `saved_restaurant_keys`, shared with the save payload |
| Resend | `braze_delivery_test`: a `restaurant_unsaved` delivery is rebuilt from its event | `ArgumentError: unknown delivery kind` | `job_arguments` accepts the kind |
| Route, controller, view | `console_test`: removal sends one delivery with the remaining list; unknown ID returns 404 and sends nothing; the page has a Turbo-off delete form | `NoMethodError: undefined method 'user_saved_restaurant_path'` | `DELETE` route, `destroy` action, Remove forms |
| Removed before its job ran | `track_job_test`: a job for a removed record sends nothing and does not raise | `ActiveRecord::RecordNotFound: Couldn't find SavedRestaurant` | `locate` returns nil; the job returns |
| Removed context not named | `test_messages`: a Canvas that started on a removed save does not name it | The nearby copy was shown instead of the saved restaurant, so the test failed on `See Lantern Row` | Context used only while the profile lists it, or when there is no list; same rule in the block and the single-file message |

Counts: 9 new Rails tests (137 to 146) and 4 new Liquid cases (180 to 184).

### Defects the tests found

1. **A queued job crashed after its record was removed (G-22).** A save that was removed before its `restaurant_saved` job ran made `GlobalID` lookup fail. The console test found it, because the job runs in the same test as the removal. Fixed in `Braze::TrackJob#locate`. The removal's own event carries the current list, so nothing is lost.
2. **A removed restaurant could still be named (D-25).** Walking the flow found it: the Canvas context carries the restaurant from the save that started it, and a Canvas can be in its delay for hours. A failing test then reproduced it, and the same rule went into the library block and the single-file message, so the parity test still holds.
3. **The CI gem audit failed (G-23).** The audit reported advisories against Rails 8.1.4 and two HTML sanitizers before this change. The fix is patch-level, within `~> 8.1.4`. Fifteen gems moved (see `rails/Gemfile.lock`).

### Mistakes made along the way

- **Two structural edits broke test files.** A replacement that spanned a class's closing `end` left the file unparseable, and an indentation mismatch in a model. Each file held only my edits, so I restored it from git and reapplied the change with anchors that begin at non-whitespace text. The next test run caught each break; none reached the record.
- **Two red steps did not fail.** The cascade and atomicity tests passed on their first run. They stay as guards, and the cascade rule is now explicit in code (D-24). The change log says so rather than counting them as red.
- **A count was wrong in my own notes.** I wrote "eight tests" for the Rails change; the diff is nine. I also wrote "eight gems"; the lockfile shows fifteen. Both are corrected in [verification.md](verification.md).

### What the process would have caught earlier

- The stage 2 check found the removal. It did not find the job crash or the message gap, because neither shows up in a diagram. The job crash came from a test; the message gap came from walking the flow. Stage 7d in [process.md](process.md) now makes that walk a required step after each slice.

### Verification

| Check | Result |
|---|---|
| `bin/ci` (style, gem audit, importmap audit, Brakeman, Rails tests, seeds) | All steps passed |
| Rails tests | 146 runs, 0 failures, 0 errors |
| RuboCop | 98 files, no offenses |
| Brakeman | No warnings |
| bundler-audit | No vulnerabilities |
| Liquid tests | 184 passed |

### Files changed

- Rails: `app/models/saved_restaurant.rb`, `app/models/app_event.rb`, `app/models/braze_delivery.rb`, `app/lib/braze/payloads.rb`, `app/jobs/braze/track_job.rb`, `app/controllers/saved_restaurants_controller.rb`, `app/views/users/show.html.erb`, `config/routes.rb`, `Gemfile.lock`
- Rails tests: `test/models/callbacks_test.rb`, `test/models/braze_delivery_test.rb`, `test/lib/braze/payloads_test.rb`, `test/integration/console_test.rb`, `test/jobs/braze/track_job_test.rb`
- Liquid: `blocks/logic/ik_get_saved_restaurant.liquid`, `03-message.liquid`, `tests/fixtures.py`, `tests/test_messages.py`
- Docs: `01-data-contract.md`, `rails/ARCHITECTURE.md`, `docs/` (journey spec, gaps, decisions, verification, process, this log, index)

### Still open

- **G-02**: transaction reversal and the reward link. This is the next slice, and it needs D-04 confirmed first.
- **G-20**: a Canvas does not exit on removal. This is a Braze setting; the repo cannot configure it.
- **G-21**: the attribute list is built when the job runs, not when the event happened. The fix is to snapshot the list on the event.
- **D-01, D-02**: the one-reward rule and the Saturday follow-up are product decisions. This change does not answer them.
- **Customer validation**: none of this was tested with a customer.
