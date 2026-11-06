# Verification

How to rerun each check in this repo, the last recorded result, and what was not run. Update the results table whenever a check is run.

## Commands and results

| Check | Command | Last result | Date | Run here? |
|---|---|---|---|---|
| Liquid blocks, messages, parity, bundle | `cd liquid && python -m pytest tests -q` | 184 passed | 2026-11-06 | Yes |
| Rails models, payloads, outbox, export, controllers, console | `cd rails && bin/ci` (WSL2) | 146 runs, 0 failures, 0 errors. RuboCop: 98 files, no offenses. Brakeman: no warnings. bundler-audit: no vulnerabilities. Importmap audit: passed. Seeds replant: passed | 2026-11-06 | Yes |
| Rails contract test (payload shape vs. `01-data-contract.md`) | Included in the Rails run | Passed, including the save and purchase samples in section 3 | 2026-11-06 | Yes |
| Warehouse checks | Run `sql/00`, `sql/01`, `sql/02`, then `sql/03_checks.sql` in a Snowflake worksheet | 11 of 11 (per `sql/results/`; not re-run here) | Recorded earlier | No |
| Braze trial render | Preview in the Braze trial workspace (`liquid/README.md`) | Recorded in `liquid/README.md` | Recorded earlier | No |

## Environment for the Liquid run

- Windows, Python 3.13.5
- `python-liquid` 1.12.1 and `pytest` 9.2.0, from `liquid/requirements.txt`
- 184 tests, 1 deprecation warning from `anyio`'s pytest plugin (no effect on results)

## Rails run

Ruby 3.4.12 runs in WSL2 Ubuntu through `mise`. Start the command with `bash -ic`, so the `mise` shim loads; a plain `bash -lc` does not find Ruby. Native Windows Ruby is not supported (`rails/README.md`). The full check is `bin/ci`, which is the same script CI runs. To run only the tests:

```bash
cd /mnt/c/Users/aaron/dev/clients/inkind/inkind-first-credit-journey/rails
bin/rails test
```

Then write the pass count and the date into the table above.

## Regenerating previews

```bash
python liquid/tests/build_previews.py              # HTML and text previews
python liquid/tests/build_previews.py --screenshots  # adds PNGs (needs playwright)
```

## What is not verified by this repo

- Braze Canvas settings: timing, control split, conversion window, re-entry. These live in the Braze UI (G-08).
- Braze delivery: the repo never sends. The `http` mode is covered by mocked tests only.
- Live Snowflake data: the SQL checks use fictional data in `INKIND_POC`.
- Customer behaviour: see [customer-validation.md](customer-validation.md).

## Latest pass: remove a saved restaurant (2026-11-06)

- Rails: `bin/ci` passed, 146 runs (the earlier baseline was 137; nine tests were added for this change).
- Liquid: 184 passed (the earlier baseline was 180; four cases were added for the removed Canvas context).
- Dependencies: the Gem audit failed before this change on advisories against Rails 8.1.4 and two sanitizers. Fifteen gems were updated within `~> 8.1.4`: the Rails 8.1 family from 8.1.4 to 8.1.4.1, loofah from 2.25.2 to 2.25.3, and rails-html-sanitizer from 1.7.1 to 1.7.2. `rails/Gemfile.lock` is the only dependency file changed.
- Details: [change-log.md](change-log.md).

## Previous pass (docs refactor)

- Moved the earlier reconstruction and audit files out of `docs/` into `refs/` (git-ignored).
- Created the files in this folder.
- Corrected two claims in `01-data-contract.md`: `search_performed` is marked deferred, and the batching line now matches the code.
- Verified the Liquid test count.
- Added a link from the root `README.md` to this folder.
