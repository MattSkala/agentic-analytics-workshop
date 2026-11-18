-- One row per visit.
--
-- A table, not a view: the source is 366 daily tables and every query against
-- the wildcard pays to open all of them. Read it once here; everything else
-- reads this table.
--
-- A visit that crosses midnight (Pacific time) is exported twice, once in each
-- day's table, with the same visitor and visit id. 898 visits are affected.
-- The two halves hold different hits, so they are merged, not de-duplicated:
-- dropping one would lose its revenue.
{{ config(materialized='table') }}

with exported_rows as (

    select
        concat(fullVisitorId, '-', cast(visitId as string)) as session_id,
        fullVisitorId as visitor_id,
        visitNumber as visit_number,
        timestamp_seconds(visitStartTime) as started_at,
        parse_date('%Y%m%d', date) as export_date,
        channelGrouping as channel,
        trafficSource.source as source,
        trafficSource.medium as medium,
        device.deviceCategory as device_category,
        geoNetwork.country as country,
        coalesce(totals.transactions, 0) as orders,
        coalesce(totals.transactionRevenue, 0) / 1e6 as revenue_usd -- source stores micros
    from {{ source('ga360', 'sessions') }}

)

select
    session_id,
    any_value(visitor_id) as visitor_id,
    min(visit_number) as visit_number,
    min(started_at) as session_start_at,
    min(export_date) as session_date,
    -- attributes come from the first half of a split visit
    any_value(channel having min started_at) as channel,
    any_value(source having min started_at) as source,
    any_value(medium having min started_at) as medium,
    any_value(device_category having min started_at) as device_category,
    any_value(country having min started_at) as country,
    sum(orders) as orders,
    sum(revenue_usd) as revenue_usd
from exported_rows
group by session_id
