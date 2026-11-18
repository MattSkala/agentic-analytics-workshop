# Agentic analytics workshop: step-by-step guide

One business question, taken from raw data to a dashboard with Claude Code:

> **What can we afford to pay for a new visitor, by marketing channel?**

You will explore a BigQuery dataset, catch a number that looks right and is
wrong, build tested dbt models, make a dashboard two ways, and package the
routine as a skill. The finished result is this repository.

The data is the public Google Analytics 360 sample: one year of real visits to
the Google Merchandise Store (1 August 2016 to 1 August 2017). It never
changes, so your numbers should match the ones below exactly.

| # | Step | Time | Claude Code concept |
|---|---|---|---|
| 0 | [Setup](#0-setup-before-the-workshop) | before | — |
| 1 | [Meet Claude Code](#1-meet-claude-code-9-min) | 9 min | CLI, permissions, `AGENTS.md` |
| 2 | [Analysis](#2-analysis-11-min) | 11 min | CLI tools, checking the answer |
| 3 | [Engineering](#3-engineering-13-min) | 13 min | Plan mode, verification loop |
| 4 | [A dashboard in minutes](#4-a-dashboard-in-minutes-4-min) | 4 min | Claude Dashboards |
| 5 | [A dashboard as code](#5-a-dashboard-as-code-7-min) | 7 min | Shipped skills, MCP |
| 6 | [Your own skill](#6-your-own-skill-5-min) | 5 min | Skills |
| 7 | [Take it to Fabric and Power BI](#7-take-it-to-fabric-and-power-bi-6-min) | 6 min | — |
| 8 | [Optional: a third dashboard in Lightdash](#8-optional-a-third-dashboard-in-lightdash-10-min) | 10 min | Vendor skills, semantic layer |

With five minutes of framing at the start, steps 1 to 7 fill one hour. Step 8
is for when there is time left, or for home.

Each step has a **prompt** to paste, **what you should see**, the **point** of
the step, and a **fallback**: the finished file in this repo, to open if the
live run stalls.

---

## 0. Setup (before the workshop)

You need:

- [Claude Code](https://claude.com/claude-code)
- [uv](https://docs.astral.sh/uv/) (installs Python, dbt and dbt Charts for you)
- The [gcloud CLI](https://cloud.google.com/sdk/docs/install) (includes `bq`)
- A Google Cloud project with BigQuery enabled. The reference run billed about
  2 GB across roughly 80 queries (BigQuery charges a 10 MB minimum per query).
  The free tier is 1 TB of queries a month.

**No credit card?** A new Google Cloud project with no billing account runs
BigQuery in sandbox mode, which is free: 10 GB of storage and 1 TB of queries
a month. Two things to know. Tables and views expire after 60 days, so rerun
`uv run dbt build` if yours have gone. Statements that change rows in place
(`insert`, `update`, `merge`) are not allowed; this project does not use any,
because every model is rebuilt whole. The reference run used a project with
billing enabled, so the sandbox route is untested here.

```bash
gcloud auth login
gcloud auth application-default login     # dbt and dbt Charts use this
export GCP_PROJECT=your-project-id        # the project that pays for queries
```

Then pick one of two ways to work.

**A. Run the finished project** (10 minutes, good for reading along):

```bash
git clone https://github.com/MattSkala/agentic-analytics-workshop.git
cd agentic-analytics-workshop
uv sync
uv run dbt debug          # expect: All checks passed!
uv run dbt build          # expect: PASS=18 WARN=0 ERROR=0
uv run dct serve          # opens the board in your browser
```

**B. Rebuild it from scratch** (what the live workshop does): make an empty
folder and copy only the three setup files into it.

```bash
mkdir my-run && cd my-run
cp ../agentic-analytics-workshop/{pyproject.toml,uv.lock,profiles.yml} .
uv sync
claude
```

Everything else in this repo is what Claude produces in steps 1 to 6. Keep the
clone open next to you to compare.

Sharing one Google Cloud project with other attendees? Give yourself a private
dataset: `export DBT_DATASET=playground_yourname`.

---

## 1. Meet Claude Code (9 min)

### 1.1 Start it and let it look around

```
Explore bigquery-public-data.google_analytics_sample with the bq CLI. It has
one table per day, named ga_sessions_YYYYMMDD. Tell me the date range, how
many visits and visitors there are, total revenue, and which columns matter
for marketing analysis. Dry-run every query first and tell me the bytes. Never
select the hits column.
```

**What you should see.** Claude asks permission before its first `bq` command.
It reports 366 daily tables from 1 August 2016 to 1 August 2017, 903,653 visit
rows, 714,167 visitors and $1,540,071 of revenue, with revenue stored in
millionths of a dollar. Each query scans 30 to 40 MB and takes about ten
seconds, because it opens all 366 tables.

**The point.** Claude Code is a terminal program that runs the same commands
you would. Nothing was configured for BigQuery: `bq` was already installed, so
Claude used it.

**Try the permission modes.** Press `Shift+Tab` to cycle between asking before
every action, auto-accepting file edits, and plan mode (read-only until you
approve a plan).

### 1.2 Write down what it learned

```
Write an AGENTS.md for this folder with what you just learned: how to query the
dataset, the cost rules I gave you, and notes on the columns.
```

Then add what the data cannot tell it. Type this yourself or paste it:

```
Add these business definitions to AGENTS.md:
- Our question is about acquisition: what a new visitor is worth.
- A visitor's revenue is credited to the channel of their first visit.
- The value window is 90 days from the first visit. It is revenue, not margin.
```

**The point.** `AGENTS.md` is loaded into every session in this folder. It is
where your team's definitions and rules live, so you say them once. Nothing in
the tables says which channel should get the credit; that is a decision.

`AGENTS.md` is the name other coding agents read too, so one file serves
whichever agent your team uses. Claude Code loads it on its own (checked on
version 2.1.326) and also reads the older name, `CLAUDE.md`.

**Fallback:** [`AGENTS.md`](AGENTS.md)

### 1.3 Make the safe things frictionless

Copy [`.claude/settings.json`](.claude/settings.json) into your folder (create
the `.claude` directory first), then restart `claude`.

**What you should see.** Dry runs, `dbt` and `dct` commands no longer ask for
permission. Real `bq query` runs still do, and `bq rm`, `bq mk` and similar are
refused outright.

**The point.** Free, read-only actions are pre-approved; anything that costs
money or changes data still needs you. Treat this file as a seatbelt. The real
guardrails are a read-only role in the warehouse and the 1 GB cap per query in
[`profiles.yml`](profiles.yml).

---

## 2. Analysis (11 min)

### 2.1 Ask the question the way a stakeholder would

```
What is a visit worth, by channel? I want to know how much we can afford to
pay per visit in each channel.
```

**What you should see.**

| Channel | Visits | Revenue per visit |
|---|---|---|
| Display | 6,262 | $12.51 |
| Referral | 104,838 | $6.21 |
| Direct | 143,026 | $3.04 |
| Paid Search | 25,326 | $1.72 |
| Organic Search | 381,561 | $0.86 |
| Social | 226,117 | $0.02 |

It reads like an answer: bid up to $12.51 for a display visit and $1.72 for a
paid search one.

### 2.2 Challenge it

```
I will use this to decide what to pay to acquire a new visitor. What is wrong
with using revenue per visit for that? Fix it and show me both versions side
by side.
```

**What you should see.** Claude finds three problems and corrects each:

- **Visits are not people.** Loyal customers return many times and inflate
  the average. Follow each person from their first visit instead.
- **Not everyone is new.** 1.8% of visitors were already customers before the
  data starts, and they bring 17% of the revenue. A new visitor is one whose
  first visit carries visit number 1.
- **Not everyone has had time.** Give every visitor the same 90 days, and
  count only those first seen by 3 May 2017.

| First channel | Revenue per visit | Per new visitor, first visit | Per new visitor, 90 days |
|---|---|---|---|
| Referral | $6.21 | $2.53 | $8.23 |
| Display | $12.51 | $2.27 | $7.57 |
| Direct | $3.04 | $1.06 | $4.29 |
| Paid Search | $1.72 | $0.99 | $2.57 |
| Organic Search | $0.86 | $0.40 | $1.03 |
| Social | $0.02 | $0.01 | $0.01 |

Revenue per visit was wrong in both directions: it overstates Display by 65%
and understates Paid Search by a third. Across all channels a new visitor is
worth $1.66 over 90 days, 3.3 times what the first visit alone earns.

Claude often raises some of this in step 2.1 without being asked. If it does,
say so to the room and move on.

**The point.** The first answer was correct SQL for the question as asked. It
was the wrong number to act on. Your job moves from writing the query to
questioning the result.

### 2.3 Make the lesson permanent

```
Add what we just learned to AGENTS.md: the definition of a new visitor and a
maturity rule for any value measured over a time window.
```

**Fallback:** the "Business definitions" section of [`AGENTS.md`](AGENTS.md),
and [`analyses/channel_value_exploration.sql`](analyses/channel_value_exploration.sql).

---

## 3. Engineering (13 min)

### 3.1 Plan before building

Press `Shift+Tab` until you are in plan mode, then:

```
Turn this analysis into a dbt project. Staging: one row per visit from the
daily tables, built as a table so we stop paying to open 366 tables. Marts:
dim_visitors (one row per visitor with first channel and revenue at the first
visit and within 7, 30, 60 and 90 days) and visitor_value_by_channel (by first
channel and month, new and mature visitors only). Follow AGENTS.md. Add tests
for keys, missing values and the list of channels.
```

Read the plan, push back on anything you disagree with, then approve it.

**The point.** Plan mode is where you review the design. It is far cheaper to
correct a plan than a finished set of models.

### 3.2 Build and let a test fail

```
Run the build and all the tests.
```

**What you should see.** The models build, and one test fails: the uniqueness
test on the visit key finds **898 visits that appear twice**.

### 3.3 Investigate; do not just make it green

```
Don't change the test yet. Investigate what is going on, tell me what you
found, and recommend what to do.
```

**What you should see.** Claude finds that a visit which crosses midnight in
the store's time zone is exported into both days' tables under the same id.
The two halves are different parts of the same visit, and 37 of them carry
revenue. The right fix is to merge the halves and add their revenue. Deleting
one half, or using `select distinct`, would pass the test and lose money.

After the fix there are 902,755 visits, revenue is unchanged at $1,540,071,
and the build prints `PASS=14 WARN=0 ERROR=0`.

**The point.** An agent that is told "make the build pass" can do so by
deleting the test or the rows. `AGENTS.md` in this repo says a failing test is
a finding to report. That one line is what makes the agent trustworthy here.

**Fallback:** [`models/`](models), especially the comment at the top of
[`models/staging/stg_sessions.sql`](models/staging/stg_sessions.sql)

---

## 4. A dashboard in minutes (4 min)

Claude can publish a dashboard straight from the conversation: a hosted page
on claude.ai where every number shows where it came from. This is Claude
Dashboards, in beta on paid plans. On Enterprise an admin has to switch it on
under Organization settings > Artifacts.

```
Build a dashboard of what a new visitor is worth by first channel, from the
visitor_value_by_channel table. Show the 90-day value, how much of it arrives
after the first visit, how it builds up over the 90 days, the share who buy,
and how the value changes by month of first visit. Add a date range control
for the month of first visit.
```

**What you should see.** Claude creates the dashboard and gives you a link.
The page has headline numbers, a line by month of first visit, a chart by
channel, a line per channel showing value building up over 90 days, and a
table, with two month pickers that narrow every figure at once.
Open Sources beside the page to see the query and the calculation behind each
figure.

For live data, connect BigQuery under Connectors in claude.ai first, then run
`/mcp` in Claude Code and sign in to the same connector. The dashboard then
stores a query, not a copy of the rows: it runs each time someone opens,
refreshes or filters the page, with that reader's own BigQuery access. A
reader without access to the table sees nothing, unless you choose "Load data
using: Your access" in Sources, which runs the query as you for everyone.
Without a connector, Claude builds the same page from an exported file.

**The point.** From question to a page you can share took minutes and no
repository. That is right for exploring and for a one-off answer. What it
does not give you is a diff, a review, or a definition that lives next to the
models. For a dashboard the business will rely on, see the next step.

---

## 5. A dashboard as code (7 min)

### 5.1 Add dbt Charts

```bash
uv run dct init
```

This creates `charts/`, `dbt_charts.yml`, and a skill at
`.claude/skills/dct/SKILL.md`. Open that file: it is 20 lines that tell Claude
to run `dct skills chart` before touching a board.

**The point.** This is a skill written by a tool vendor. Installing the tool
taught your agent how to use it.

### 5.2 Build the board

```
Build a dbt Charts board that answers "What can we afford to pay for a new
visitor?". Include headline numbers, a line of the value by month of first
visit, a bar per first channel that splits the 90-day value into the first
visit and later visits, a line showing how value builds up over the 90 days,
and a table. Add a date range control that filters everything by month of
first visit. Read from the dbt marts. Render it to PNG and check it yourself
before you show me.
```

Then look at it:

```bash
uv run dct serve
```

**What you should see.** A board like [`docs/board.png`](docs/board.png), with
a "First visit between" control at the top. Try it from the terminal too:

```bash
uv run dct render charts/channel_value.yml --format text \
  --var 'first_visit=["2017-01-01","2017-04-30"]'
```

For January to April 2017 the headline changes from 554,755 visitors at $1.66
to 202,007 visitors at $1.53.

The line by month shows the value of a new visitor falling from $2.64 for
August 2016 to $0.97 for November, when a surge of 94,732 mostly low-value
visitors arrived, then settling around $1.50.

**What went wrong in the reference run, and how it was caught.** Worth telling
the room, because each one was found by checking, not by trusting:

- BigQuery rejected two of the board's queries ("aggregations of aggregations
  are not allowed"): a column alias had the same name as the column it summed.
  Caught by the check `dct serve` runs on every board.
- The headline read "550k" for 554,755 visitors. Rounding had dropped nearly
  5,000 people. Caught by looking at the rendered image.
- Channels were listed alphabetically, so the chart did not read as a ranking.
  Caught by looking at the image.
- A headline label was cut off. Caught by a `dct` warning.
- The first draft of the line by month would have ended in a spike to $4.89.
  The last month, May 2017, holds only three days of visitors. Caught by
  reading the monthly numbers before charting them. The model now carries an
  `is_complete_month` flag and charts over time leave partial months out.
- The labels at the end of each line rounded to whole dollars, so $1.56 read
  as "$2". Caught by looking at the image; the chart now uses a plain legend.

**The point.** The board is a YAML file. A reviewer can read the diff, and the
agent can validate and render it without a browser.

**Fallback:** [`charts/channel_value.yml`](charts/channel_value.yml)

### 5.3 The same tool through MCP (if time allows)

Copy [`.mcp.json`](.mcp.json) into your folder, restart `claude`, approve the
server when asked, then type `/mcp`.

**What you should see.** A `dbt-charts` server with ten tools, including
`render_board`, `execute_sql` and `describe_board`.

**The point.** MCP gives an agent tools when there is no terminal, for example
in a chat app or an IDE panel. When a good CLI exists, as here, the CLI is
usually simpler; the dbt Charts README says the same. Reach for MCP when a
system has no CLI or when access has to be brokered.

---

## 6. Your own skill (5 min)

Open [`.claude/skills/add-metric/SKILL.md`](.claude/skills/add-metric/SKILL.md).
It is the routine from steps 2 to 5 written down as nine steps: define,
prototype, model, document, test, build, chart, verify, report.

Copy the `add-metric` folder into your `.claude/skills/`, then:

```
/add-metric share of new visitors who buy within 90 days
```

**What you should see.** Claude prototypes the number (1.22% overall, from
6.32% for Referral down to 0.03% for Social), adds `buyers_90d` and
`conversion_rate_90d` to the mart with a test, adds a headline number and a
chart, rebuilds and re-renders. The build now prints `PASS=15`. (The finished
repo prints `PASS=18`: step 8 adds one more model with two tests.)

**The point.** `AGENTS.md` holds facts that are always true. A skill holds a
procedure you want done the same way every time, loaded only when it is needed.
When you notice you have explained a routine twice, write the skill.

---

## 7. Take it to Fabric and Power BI (6 min)

Nothing in the method depends on BigQuery. Five things carried the workshop:

| What it does | Here | On Microsoft Fabric / Power BI |
|---|---|---|
| Context the agent always has | `AGENTS.md` | The same file |
| Warehouse access from the terminal | `bq` | `sqlcmd` or the Fabric CLI |
| Transformations with tests | dbt + `dbt-bigquery` | dbt + `dbt-fabric` |
| Dashboards as text files | dbt Charts with `[bigquery]` | dbt Charts with `[fabric]`, or Power BI project files (PBIP / TMDL) |
| A repeatable routine | `add-metric` skill | The same skill, different commands |

To port this repo: change the adapter in `pyproject.toml` and `profiles.yml`,
replace the `bq` lines in `AGENTS.md` and `.claude/settings.json` with your
SQL client, and point `_sources.yml` at your tables. The Fabric column was not
tested as part of this workshop.

The questions to ask of any stack:

1. Can the agent **read** the warehouse cheaply and safely?
2. Is every artifact a **text file** in git?
3. Is there a command that says whether the work is **correct** (compile,
   test, validate, render)?

If all three are yes, the approach works.

---

## 8. Optional: a third dashboard in Lightdash (10 min)

Only if there is time left. Lightdash is an open-source BI tool that reads a
dbt project. It adds what the other two dashboards do not have: a semantic
layer, where a metric is defined once and business users explore it without
writing SQL.

You need a running Lightdash instance (self-hosted with Docker, or Lightdash
Cloud) and its CLI:

```bash
npm install -g @lightdash/cli
lightdash login http://localhost:8080      # or your cloud address
```

### 8.1 Let the tool teach the agent

```bash
uv run lightdash install-skills --path .
```

This downloads four skills into `.claude/skills/`. The one that matters is
`developing-in-lightdash`: the YAML formats for metrics, charts and
dashboards, with JSON schemas.

**The point.** The same idea as `dct init` in step 5: installing the tool
teaches your agent how to use it.

### 8.2 Add the semantic layer and deploy

```
Add a Lightdash semantic layer to visitor_value_by_channel: metrics for new
visitors, revenue per new visitor at the first visit and over 90 days, and the
share who buy within 90 days. Compute every ratio from sums, and hide the
pre-computed ratio columns so nobody can average them. I also want a line
chart of value building up at 0, 7, 30, 60 and 90 days, with the days on the
x-axis: add whatever model that needs. Then deploy to a new Lightdash project
called "Agentic Analytics Workshop".
```

**What you should see.** A `config: meta:` block on the model in
[`models/marts/_marts.yml`](models/marts/_marts.yml), and a new model,
[`visitor_value_curve`](models/marts/visitor_value_curve.sql), which turns the
five revenue columns into five rows. Lightdash's explorer plots one row per
point, so "days since the first visit" has to be a column before it can be an
axis. dbt Charts and the Claude Dashboard did not need this, because their
charts carry their own SQL or code. Then
`Compiled 2 explores, SUCCESS=2 ERRORS=0` and a new project.

**Know what deploy does with credentials.** Creating a project copies the
warehouse connection from `profiles.yml` into Lightdash. With the `gcloud`
login used in this workshop, that is your own Google login. On an instance
running on your laptop that is acceptable. On a shared or cloud instance, use
a service account with read-only access instead.

### 8.3 Build the dashboard as code

```
Build a Lightdash dashboard as code that answers the same question: three
headline numbers, a line of the value by month of first visit, a stacked bar
of first-visit and later value by first channel, a line per channel of value
building up over 90 days, the share who buy by channel, and a table. Add a dashboard date filter on the month of first
visit. Leave out channels with fewer than 1,000 new visitors. Lint it, upload
it, then run each chart and check the numbers match the dbt Charts board.
```

**What you should see.** Eight chart files and one dashboard file under
[`lightdash/`](lightdash), `All Lightdash Code files are valid!` from the
lint, and `Total charts created: 8, Total dashboards created: 1` from the
upload. The dashboard has a "First visit between" filter at the top, which
reaches the chart from the second model through a per-tile target. Running the charts returns the same figures as the other two
dashboards: 554,755 new visitors, $1.66 over 90 days, 1.22% who buy.

Open the dashboard in the browser, then click into a chart and choose
"Explore from here": that is the part the other two tools do not offer.

**What went wrong in the reference run.**

- The lint rejected every chart at first: `metricQuery` needs a
  `tableCalculations` list even when it is empty. The schema caught it before
  anything was uploaded.
- `lightdash export-chart-image` failed with a server error, because the
  local instance had no headless browser service. So the agent could check
  the numbers but not the look. With dbt Charts it could do both.

**The point.** All three dashboards show the same numbers because all three
read the same tested dbt model. What differs is where the definitions live
and who can change them:

| | Claude Dashboard | dbt Charts | Lightdash |
|---|---|---|---|
| Made by | Asking | Asking | Asking |
| Lives in | A hosted page | A YAML file in the repo | A server, with YAML you can sync |
| Metric definitions | In the page's queries | In each board's SQL | Once, in dbt YAML |
| A chart with a new shape needs | More page code | More board SQL | Sometimes a new dbt model |
| Business users can explore | By asking Claude | Only through a board's filters | Yes, without SQL |
| You have to run | Nothing | Nothing | A server |
| Agent can check the result | As text, once the page is open | Yes, renders to an image | Numbers yes; the look needs a headless browser service |

Lightdash's own guidance is that the server is the source of truth for charts
and dashboards, and that downloaded YAML should not be committed unless the
team wants content under version control. This repo keeps the files so you
can upload them.

**Fallback:** [`lightdash/`](lightdash) and the `config: meta:` block in
[`models/marts/_marts.yml`](models/marts/_marts.yml)

---

## Limits of the answer

Say these out loud when you present the result:

- It is revenue, not margin. Multiply by your margin before setting a bid.
- First-touch attribution gives all credit to the first channel, even when a
  later paid click closed the sale.
- The Referral channel is mislabelled in this dataset: 94% of its revenue has
  no recorded referrer. Do not read it as partner traffic.
- The data is from 2016 and 2017, from one store.

## Clean up

```bash
bq rm -r -f -d "$GCP_PROJECT:agentic_analytics_playground"
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Env var required but not provided: 'GCP_PROJECT'` | `export GCP_PROJECT=your-project-id` in the shell before starting `claude` |
| `dbt debug` fails on credentials | `gcloud auth application-default login` |
| Claude does not seem to know what is in `AGENTS.md` | Update Claude Code. On an old version, `ln -s AGENTS.md CLAUDE.md` in the project folder |
| `Access Denied` creating the dataset | You need BigQuery Data Editor and Job User on the project |
| Queries on `ga_sessions_*` are slow | Expected: each one opens 366 tables. Query `stg_sessions` once it exists |
| A board query fails with "aggregations of aggregations" | A select alias shadows a column used in `having`. Qualify the column with a table alias |
| `dct validate` errors on a column named like a date part | Move the `date_trunc` into a mart column |
| `dct serve` says the port is taken | `uv run dct serve --port 8081` |
| The MCP server does not show in `/mcp` | Restart `claude` in the folder that holds `.mcp.json` and approve it |
| Claude does not offer to build a dashboard in step 4 | Dashboards is in beta on paid plans and may be switched off for your organisation |
| `lightdash deploy` cannot find dbt | Run it as `uv run lightdash deploy` so the project's dbt is on the path |
| `lightdash lint` says `tableCalculations` is missing | Add `tableCalculations: []` under `metricQuery` in the chart |
| `dct serve` and Lightdash both want port 8080 | `uv run dct serve --port 8081` |
| Tables are missing after two months on a no-billing project | Sandbox tables expire after 60 days. Run `uv run dbt build` again |
