# Runnable SQL

A small proof of concept for the SQL in `01` and `02`: synthetic sample data, the Cloud Data Ingestion view, both audience spot checks, and pass/fail checks. All data is made up.

## Run it

In a Snowflake worksheet (a free trial works), run the files in order:

| File | What it does |
|---|---|
| `00_sample_data.sql` | Creates an extra-small warehouse that suspends after 60 seconds idle, and `INKIND_POC.FIRST_REWARD` with ten users, each one a case the journey has to handle |
| `01_braze_view.sql` | Creates the view from `01-data-contract.md` and shows the rows Braze would read |
| `02_audience_checks.sql` | Runs the warehouse spot checks for both Canvases in `02-journey.md` |
| `03_checks.sql` | Prints one row per check; every row should say PASS |

Run in Snowflake on 2026-11-01: 11/11 PASS ([results](results/03_checks_2026-11-01.csv), [screenshot](results/03_checks_2026-11-01.png)). [Watch it run (4:43)](https://youtu.be/OnmBVC8vrwE).

To clean up: `DROP DATABASE INKIND_POC; DROP WAREHOUSE INKIND_POC_WH;`

The last check shows a limit of the view as written: a purchase that reaches the warehouse after a sync, with an older event time, would be skipped. That's the production note under the view in `01`.
