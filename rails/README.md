# rails/: the backend half of the data contract

The Rails app that owns the real-time events, the saved restaurants, and the rows that reach the warehouse. For each action it builds the exact Braze `/users/track` body from [`01-data-contract.md`](../01-data-contract.md) §3 once, stores it in an outbox, exports rows to Snowflake with their load time, and previews what Cloud Data Ingestion would sync next. The design is in [`ARCHITECTURE.md`](./ARCHITECTURE.md).

> **Sending to Braze.** The available Braze workspace is a trial, which doesn't include the REST API, Cloud Data Ingestion or Data Transformation. So Braze runs in **record mode** only (§6.4). The HTTP adapter exists behind a flag and is covered by WebMock tests, but has never run against a live workspace. Say so wherever it's mentioned.

**All data is fictional.** The ten sample users, the `demo-` location IDs, the `example.com` emails, and the sample images are made up or generated for this repo.

---

## Setup (WSL Ubuntu)

Rails runs in WSL2 Ubuntu. Native Windows Ruby isn't supported. The repo has one working copy, edited in VS Code on Windows. Ruby commands run in WSL against the same folder, at `/mnt/c/…/rails`. Don't create a second clone.

1. **Install Ruby with Mise.** Mise installs the version in `.ruby-version` (3.4.12) without sudo:

   ```bash
   curl https://mise.run | sh
   echo 'export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"' >> ~/.bashrc
   exec bash -l
   cd /mnt/c/Users/<you>/dev/clients/inkind/inkind-first-credit-journey/rails
   mise install
   ruby -v   # 3.4.12
   ```

2. **Install and prepare the app:**

   ```bash
   bin/setup
   ```

3. **Credentials.** `config/master.key` is git-ignored. Keep a copy outside the repo; without it the encrypted credentials can't be read. Put the master key in `config/master.key`, then check the keys with `bin/rails credentials:show` (values are shown, so don't paste the output anywhere). The Snowflake settings are the account, user, role `SYSADMIN`, warehouse `INKIND_POC_WH`, database `INKIND_POC`, schema `RAILS_DEMO`, and `private_key_path`. The key file stays in your home folder, for example `~/.snowflake/rsa_key.p8`. **Never put the private key in the repo.** `ARCHITECTURE.md` §4 lists every key.

4. **The warehouse schema.** `sql/10_rails_demo_schema.sql` clones `FIRST_REWARD` into `RAILS_DEMO`. `bin/rails demo:reset` re-runs it for you (below). To run it by hand as SYSADMIN, use the Snowflake CLI, `snow sql -f sql/10_rails_demo_schema.sql`. `FIRST_REWARD` isn't changed, so `sql/03_checks.sql` still passes there.

## Run it

```bash
SOLID_QUEUE_IN_PUMA=1 bin/dev     # the app, with background jobs running inside Puma
```

- App: http://localhost:3000. Users, Deliveries, and Warehouse are in the top bar.
- Jobs dashboard: http://localhost:3000/admin/jobs (no login in development).
- To run jobs on their own, `bin/jobs` starts a worker without the web server.

`bin/dev` and `bin/jobs` use Solid Queue, so background work needs one of them running.

### Reset the demo

```bash
bin/rails demo:reset
```

This resets and seeds the local database, re-runs `sql/10` in Snowflake, and clears the CDI watermark. It prints one line:

```
users=10 pending_exports=0 rails_demo_u1001_reward=unused ($25)
```

It only runs in development. **Stop `bin/dev` first**, because SQLite files can't be dropped while the server holds them.

## The two-minute demo

Use http://localhost:3000 with `bin/dev` running.

1. **Save.** Open `u_1001`. Under *Save a restaurant*, pick **Lantern Row** and save it. The outbox shows a `restaurant_saved` delivery, and its `saved_restaurants` list now ends with `r_101`.
2. **Pay.** Under *Pay*, pick Lantern Row, enter subtotal `62.40`, tip `12`, and tick *Use the referral reward*. The outbox shows a `purchase` delivery with `reward_applied: true` and `reward_amount: 25`. The user's reward now shows as used.
3. **Re-run the job.** This re-runs the save's job; it should still leave one delivery:

   ```bash
   bin/rails runner 'save = User.find_by!(external_id: "u_1001").saved_restaurants.find_by!(restaurant: Restaurant.find_by!(key: "r_101")); Braze::TrackJob.perform_now("restaurant_saved", save.to_global_id.to_s); puts BrazeDelivery.where(idempotency_key: "restaurant_saved:#{save.id}").count'
   ```

   It prints `1`.
4. **Export.** Open **Warehouse** and press *Run export now*. The pending counts drop to zero. The transaction and the redeemed reward are now in `RAILS_DEMO`. Running the export again sends nothing and adds no rows, because the warehouse writes are MERGEs on a key.
5. **Preview.** Open **Warehouse → Cloud Data Ingestion preview**. `u_1001`'s row shows `first_reward_amount`, `first_reward_display`, and `first_reward_min_spend` as `null`, with a newer `UPDATED_AT`. This page only previews what Braze's sync would pick up. Braze runs the real sync.
6. **Refuse.** Under *Pay* for `u_1004`, enter subtotal `38.00` and tick *Use the referral reward*. The page refuses it with "Subtotal must be at least $50.00 to use this reward", and nothing is sent.

## Tests and checks

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

All HTTP goes through WebMock, so the tests need no Snowflake or Braze credentials. CI (`.github/workflows/rails-tests.yml`) runs the same three checks with no secrets.

## Layout

- `app/lib/braze/`: payloads, the validator, the client (record mode, plus the WebMock-tested HTTP adapter)
- `app/jobs/braze/track_job.rb`: the outbox job. The payload is built once and stored
- `app/services/payments/record.rb`: records a payment and redeems the reward in one transaction
- `app/lib/snowflake/`: the key-pair JWT and the SQL API client
- `app/lib/warehouse/`: the export, its MERGE statements, and the CDI preview
- `app/lib/demo/reset.rb`: the demo reset
- `db/seeds.rb`: the ten sample users from `sql/00`, idempotent
