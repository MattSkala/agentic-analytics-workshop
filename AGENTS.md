# Agentic analytics workshop project

A dbt + BigQuery project on the public Google Analytics 360 sample
(`bigquery-public-data.google_analytics_sample`): one year of real visits to
the Google Merchandise Store. Dashboards are in dbt Charts (`charts/`).

## Commands

- Everything runs through uv: `uv run dbt ...`, `uv run dct ...`.
- `GCP_PROJECT` must be set (the billing project). Models land in the dataset
  `agentic_analytics_playground`; override with `DBT_DATASET`.
- Build and test: `uv run dbt build`. One model and everything downstream:
  `uv run dbt build --select dim_visitors+`.
- Boards: `uv run dct validate --warehouse`, then
  `uv run dct render charts/<board>.yml --format png` and look at the image.
  `uv run dct serve` gives a live preview.
- Lightdash (optional): metrics live under `config: meta:` in
  `models/marts/_marts.yml`, content under `lightdash/`. Run
  `lightdash config get-project` before `uv run lightdash deploy` or
  `lightdash upload`, so nothing lands in the wrong project.

## Querying BigQuery

- Ad-hoc SQL goes through `bq`. Dry-run first and report the bytes:
  `bq query --use_legacy_sql=false --dry_run '<sql>'`. Then run it with
  `--maximum_bytes_billed=1000000000`.
- Read-only outside the dbt dataset: create or change tables only through dbt.
- The source is 366 daily tables (`ga_sessions_YYYYMMDD`). Queries on the
  wildcard are slow. Once `stg_sessions` exists, query that instead.
- Never select the `hits` column: it is the bulk of the 5.8 GB.

## Business definitions

- **New visitor:** a visitor whose first visit in the data has
  `visit_number = 1`. The other 1.8% were acquired before the data starts and
  bring 17% of revenue, so they must not be counted as new.
- **First channel:** the channel of a visitor's first visit. All of their
  later revenue is credited to it (first-touch attribution).
- **Value of a new visitor:** revenue per new visitor in the 90 days from the
  first visit. It is revenue, not margin.
- **Maturity rule:** a value over an N-day window only includes visitors whose
  first visit is at least N days before the last day of data (1 Aug 2017).
  For 90 days that means first seen on or before 3 May 2017. The dataset is
  static, so never use `current_date()` for this.
- **Complete months:** a chart over time only shows months that lie wholly
  inside the maturity window (`is_complete_month`). May 2017 holds three days
  of visitors and would end any trend in a false spike. Totals still count it.

## Conventions

- Layers: `models/staging` (rename, clean, one row per visit), then
  `models/marts` (tables). Marts never read sources directly.
- Marts keep additive sums next to per-visitor values. Boards roll up from the
  sums and never average an average.
- Every model has a description and `unique` + `not_null` tests on its key.
- Boards read dbt models through `{{ ref() }}`, never raw source tables.
- Marts expose the date grains boards need. Do not `date_trunc` in board SQL:
  `dct validate` 0.11 misreads BigQuery date parts such as `quarter` as
  missing columns.

## Known data quirks

- A visit that crosses midnight Pacific time is exported twice, once per day
  table, with the same visitor and visit id (898 visits). `stg_sessions`
  merges the halves. Summing is correct; de-duplicating would lose revenue.
- Revenue is stored in micros: divide `totals.transactionRevenue` by 1e6.
- The `Referral` channel is not what it sounds like: 94% of its revenue has
  `(direct)` as its source. Do not read it as partner traffic.
- 37 visits have an order but no revenue. They count as orders worth $0.

## Working rules

- A failing test is a finding. Investigate and report it; never delete or
  weaken a test to get a green build without asking.
- After changing a board, render it and check that the numbers on different
  charts agree with each other.
