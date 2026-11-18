-- The ad-hoc question from the analysis step, kept for reference.
-- "What is a visit worth, by channel?" Correct SQL, wrong number to bid with:
-- it counts visits, not people, and mixes loyal returning visitors with new
-- ones. Compare with visitor_value_by_channel.
select
    channel,
    count(*) as visits,
    round(sum(revenue_usd)) as revenue_usd,
    round(sum(revenue_usd) / count(*), 2) as revenue_per_visit
from {{ ref('stg_sessions') }}
group by channel
order by revenue_usd desc
