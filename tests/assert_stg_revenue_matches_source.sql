-- Staging must neither lose nor invent money: its revenue has to equal the raw
-- export's. The uniqueness test on session_id cannot catch this. Keeping only
-- one half of a visit split at midnight leaves the key unique and drops the
-- revenue of the other half.
with source_total as (

    select round(sum(coalesce(totals.transactionRevenue, 0)) / 1e6, 2) as revenue_usd
    from {{ source('ga360', 'sessions') }}

),

staging_total as (

    select round(sum(revenue_usd), 2) as revenue_usd
    from {{ ref('stg_sessions') }}

)

select
    source_total.revenue_usd as source_revenue_usd,
    staging_total.revenue_usd as staging_revenue_usd
from source_total
cross join staging_total
where source_total.revenue_usd != staging_total.revenue_usd
