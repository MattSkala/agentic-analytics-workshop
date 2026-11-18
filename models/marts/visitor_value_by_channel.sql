-- One row per first channel and cohort month, for genuinely new visitors with
-- a full 90 days of history. Sums are additive, so boards can roll months up;
-- the per-visitor values are what a new visitor from that channel is worth.
select
    concat(first_channel, ' | ', cast(cohort_month as string)) as channel_month_key,
    first_channel,
    cohort_month,
    -- false for a month that is only partly inside the maturity window; trend charts skip it
    logical_and(is_complete_cohort_month) as is_complete_month,
    count(*) as new_visitors,
    sum(revenue_first_visit) as revenue_first_visit,
    sum(revenue_7d) as revenue_7d,
    sum(revenue_30d) as revenue_30d,
    sum(revenue_60d) as revenue_60d,
    sum(revenue_90d) as revenue_90d,
    countif(orders_90d > 0) as buyers_90d,
    safe_divide(sum(revenue_first_visit), count(*)) as value_first_visit,
    safe_divide(sum(revenue_90d), count(*)) as value_90d,
    safe_divide(countif(orders_90d > 0), count(*)) as conversion_rate_90d
from {{ ref('dim_visitors') }}
where is_new_visitor
    and is_mature_90d
group by first_channel, cohort_month
