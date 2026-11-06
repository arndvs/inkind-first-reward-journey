# Architecture

How the pieces of this repo fit together, in five diagrams. Each section links to the file that holds the detail. The Rails app has its own, deeper design doc in [`rails/ARCHITECTURE.md`](./rails/ARCHITECTURE.md).

Everything here is a sketch built from public documentation. All users, restaurants, and amounts are made up. Not affiliated with inKind.

---

## 1. The whole system

Two paths reach Braze. Events that start or end the journey go in real time through `/users/track`. Values computed in the warehouse go through Cloud Data Ingestion (CDI), which only reads rows with a newer `UPDATED_AT`.

```mermaid
flowchart LR
    subgraph RAILS["rails/ (the backend)"]
        PAY["Payments::Record<br/>txn + reward redemption<br/>in one transaction"]
        DB[("SQLite<br/>users, rewards, saves,<br/>transactions, app_events")]
        JOB["Braze::TrackJob<br/>after commit"]
        OUT[("braze_deliveries<br/>outbox, unique<br/>idempotency_key")]
        EXP["Warehouse::ExportJob<br/>every 10 minutes"]
        PAY --> DB
        DB -- "after_create_commit" --> JOB
        JOB --> OUT
        DB --> EXP
    end

    subgraph SF["sql/ (Snowflake)"]
        TBL[("rewards, transactions,<br/>app_events")]
        VIEW["braze_first_reward_attributes<br/>OBJECT_CONSTRUCT_KEEP_NULL"]
        TBL --> VIEW
    end

    subgraph BRAZE["Braze"]
        PROF["User profile<br/>custom attributes"]
        CAT[("restaurants_catalog")]
        CANVAS["Canvas<br/>02-journey.md"]
        MSG["Message<br/>liquid/ Content Blocks"]
        PROF --> CANVAS --> MSG
        CAT --> MSG
    end

    OUT -. "POST /users/track<br/>(record mode in this repo)" .-> PROF
    EXP -- "MERGE via SQL API" --> TBL
    VIEW -. "CDI: rows with a<br/>newer UPDATED_AT" .-> PROF
    MSG --> USER(["Push or email"])
```

| Part | Where | Detail |
|---|---|---|
| Data contract | [`01-data-contract.md`](./01-data-contract.md) | Every field, its type, and which path it takes |
| Journey | [`02-journey.md`](./02-journey.md) | Entry, filters, timing, exits, the control group |
| Message | [`liquid/`](./liquid/) | 17 Content Blocks and the messages built from them |
| Warehouse | [`sql/`](./sql/) | Sample data, the CDI view, audience checks, 11 pass/fail checks |
| Backend | [`rails/`](./rails/) | The outbox, the export, and a console to drive both |

---

## 2. A payment, end to end

The payment and the reward redemption commit together or not at all. Braze hears about the payment only after the commit, through an outbox row that makes every retry safe.

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant P as Payments::Record
    participant DB as Database
    participant Q as Solid Queue
    participant J as Braze::TrackJob
    participant BZ as Braze /users/track

    U->>P: pay, use reward
    P->>DB: BEGIN
    P->>DB: insert transaction (validations run)
    P->>DB: reward.redeemed_at = now
    P->>DB: COMMIT
    DB-->>Q: after_create_commit: enqueue TrackJob("purchase")
    Q->>J: perform
    J->>DB: find delivery by "purchase:<transaction_key>"
    alt no row yet
        J->>DB: insert delivery, payload built once
        Note over J,DB: a concurrent insert raises RecordNotUnique,<br/>and the job reuses the existing row
    else already recorded
        J-->>Q: return, nothing sent twice
    end
    J->>BZ: send the stored payload
    alt 2xx
        J->>DB: status = recorded
    else 429, 5xx or network error
        J-->>Q: retry with polynomial backoff, up to 5 attempts, then mark failed
    else other 4xx or invalid payload
        J->>DB: status = failed, not retried
    end
```

Code: [`rails/app/services/payments/record.rb`](./rails/app/services/payments/record.rb), [`rails/app/jobs/braze/track_job.rb`](./rails/app/jobs/braze/track_job.rb), [`rails/app/lib/braze/client.rb`](./rails/app/lib/braze/client.rb). The trial workspace has no REST API, so the client runs in record mode: it stores the exact request instead of sending it.

---

## 3. How the message decides what to say

The message checks the reward before anything else and stops itself when there's nothing true to promote. The abort sits in the message, not in a Content Block, so anyone reading the message sees the stop.

```mermaid
flowchart TD
    START(["Canvas step renders the email"]) --> CFG["ik_brand, ik_urls<br/>design tokens and links"]
    CFG --> RW["ik_get_reward<br/>reads first_reward_* attributes"]
    RW --> OK{"reward_ok?"}
    OK -- "no unused reward" --> A1(["abort_message: no unused reward"])
    OK -- "amount is zero" --> A2(["abort_message: reward amount is zero"])
    OK -- "minimum missing" --> A3(["abort_message: reward minimum missing"])
    OK -- "yes" --> SV["ik_get_saved_restaurant<br/>the Canvas trigger's restaurant_id,<br/>else the first saved ID,<br/>looked up in restaurants_catalog"]
    SV --> HAS{"found in the Catalog?"}
    HAS -- "yes" --> CARD["Hero card and button<br/>for the saved restaurant"]
    HAS -- "no" --> BTN["Generic hero and a<br/>'Find a spot near you' button"]
    BTN --> NB["ik_get_nearby<br/>Connected Content call"]
    NB --> NBOK{"results?"}
    NBOK -- "yes" --> LIST["'Near you' list"]
    NBOK -- "no, or call failed" --> BODY
    CARD --> BODY
    LIST --> BODY
    BODY["Hero, how to use the reward<br/>(with the minimum spend), footer"] --> SEND(["Send"])
```

Code: [`liquid/messages/first_reward.email.liquid`](./liquid/messages/first_reward.email.liquid) and [`liquid/blocks/logic/`](./liquid/blocks/logic/). The push uses the same logic blocks, and a parity test checks that both make the same offer.

---

## 4. Why `UPDATED_AT` is the load time

CDI only picks up rows whose `UPDATED_AT` is newer than its last sync. If `UPDATED_AT` were the purchase time, a record that reached the warehouse late would be skipped for good. Check 11 in [`sql/03_checks.sql`](./sql/03_checks.sql) shows the bug on purpose, and the export stamps `UPDATED_AT` with the load time in UTC.

```mermaid
sequenceDiagram
    participant APP as Backend
    participant DW as Snowflake
    participant CDI as Braze CDI

    Note over APP: Oct 14: user pays
    CDI->>DW: sync: rows with UPDATED_AT > last sync
    Note over CDI: last sync moves to Oct 20
    APP->>DW: Oct 27: the record finally arrives
    alt UPDATED_AT = purchase time (Oct 14)
        CDI->>DW: next sync: UPDATED_AT > Oct 20?
        DW-->>CDI: no rows. Braze never learns the user paid
    else UPDATED_AT = load time (Oct 27)
        CDI->>DW: next sync: UPDATED_AT > Oct 20?
        DW-->>CDI: the row, with first_reward_amount = null, so the attribute clears
    end
```

The same thing happens with a record that's only an hour late, if a sync runs in that hour.

---

## 5. What checks run, and where

```mermaid
flowchart LR
    PR(["Pull request"]) --> L["Liquid tests<br/>pytest: 180 tests<br/>blocks, messages, parity,<br/>nesting, golden cards"]
    PR --> R["Rails tests<br/>137 tests<br/>+ Brakeman + RuboCop"]
    L --> MERGE{"All green?"}
    R --> MERGE
    MERGE -- "yes" --> MAIN(["Merge"])
    MERGE -- "no" --> FIX(["Fix, push again"])

    SQL["SQL checks<br/>11 pass/fail checks"] -. "run by hand in a<br/>Snowflake worksheet" .-> SFW[("Snowflake")]
    BT["Braze trial<br/>previews per test user"] -. "loaded by hand<br/>through the dashboard" .-> BZ[("Braze")]
```

The Liquid and Rails suites run in GitHub Actions on every pull request ([`.github/workflows/`](./.github/workflows/)). The SQL checks need a Snowflake account, so they run in a worksheet, not in CI. [`04-qa-and-measurement.md`](./04-qa-and-measurement.md) has the pre-launch checks a real send would add.
