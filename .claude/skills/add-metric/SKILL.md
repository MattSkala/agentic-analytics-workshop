---
name: add-metric
description: Add a visitor or channel metric end to end - mart column, docs, test, a chart on the board - and verify it against the warehouse. Use when asked to add, track, or chart a new metric about visitors, channels, conversion, or revenue.
---

# Add a metric

Follow every step in order. Do not skip the checks; they are the point.

1. **Define it in one sentence.** Name the numerator, the denominator, the time
   window and which visitors count. Apply the business definitions and the
   maturity rule in `AGENTS.md`. If two readings are plausible, ask which one.
2. **Prototype it.** Write the SQL against `dim_visitors`, dry-run it with
   `bq`, run it, and check the result is plausible (range, nulls, one channel
   recomputed a second way). Keep the numbers; step 8 compares against them.
3. **Extend `dim_visitors` only if an input is missing.** Otherwise leave it.
4. **Add it to `models/marts/visitor_value_by_channel.sql`:** the additive
   pieces (counts or sums) first, then the metric computed from them.
5. **Document and test it in `models/marts/_marts.yml`:** a description with
   the definition and unit, plus at least a `not_null` test where it applies.
6. **Build:** `uv run dbt build --select dim_visitors+`. All tests must pass.
7. **Chart it** in `charts/channel_value.yml` (run `uv run dct skills chart`
   first if you have not read it this session). Roll up from the additive
   pieces, set the number format on the query, and place the chart in `rows:`.
8. **Verify:** `uv run dct validate --warehouse`, then
   `uv run dct render charts/channel_value.yml --format png` and look at the
   image. The new numbers must match step 2 and agree with the other charts.
   Also check that no label is cut off and that no axis exaggerates a small
   change.
9. **Report:** the definition, files changed, the headline number, and
   anything that surprised you.
