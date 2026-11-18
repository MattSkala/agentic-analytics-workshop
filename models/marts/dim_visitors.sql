-- One row per visitor, with what they were worth in the days after their
-- first visit. Value is credited to the channel of that first visit.
with sessions as (

    select * from {{ ref('stg_sessions') }}

),

first_visits as (

    select
        visitor_id,
        min(session_start_at) as first_seen_at,
        any_value(session_date having min session_start_at) as first_seen_date,
        any_value(visit_number having min session_start_at) as first_visit_number,
        any_value(channel having min session_start_at) as first_channel,
        any_value(source having min session_start_at) as first_source
    from sessions
    group by visitor_id

),

-- the dataset is static, so "today" is its last day, not current_date()
data_window as (

    select max(session_date) as last_date from sessions

),

value_windows as (

    select
        sessions.visitor_id,
        sum(if(sessions.session_start_at = first_visits.first_seen_at, sessions.revenue_usd, 0)) as revenue_first_visit,
        sum(if(timestamp_diff(sessions.session_start_at, first_visits.first_seen_at, day) < 7, sessions.revenue_usd, 0)) as revenue_7d,
        sum(if(timestamp_diff(sessions.session_start_at, first_visits.first_seen_at, day) < 30, sessions.revenue_usd, 0)) as revenue_30d,
        sum(if(timestamp_diff(sessions.session_start_at, first_visits.first_seen_at, day) < 60, sessions.revenue_usd, 0)) as revenue_60d,
        sum(if(timestamp_diff(sessions.session_start_at, first_visits.first_seen_at, day) < 90, sessions.revenue_usd, 0)) as revenue_90d,
        sum(if(timestamp_diff(sessions.session_start_at, first_visits.first_seen_at, day) < 90, sessions.orders, 0)) as orders_90d
    from sessions
    inner join first_visits using (visitor_id)
    group by sessions.visitor_id

)

select
    first_visits.visitor_id,
    first_visits.first_seen_at,
    first_visits.first_seen_date,
    date_trunc(first_visits.first_seen_date, month) as cohort_month,
    first_visits.first_channel,
    first_visits.first_source,
    -- visitors first seen mid-history were acquired before the data starts
    first_visits.first_visit_number = 1 as is_new_visitor,
    -- only visitors with a full 90 days of data behind them are comparable
    first_visits.first_seen_date <= date_sub(data_window.last_date, interval 90 day) as is_mature_90d,
    -- a cohort month is complete only when its last day is inside the 90-day
    -- window too; a partial month (May 2017 holds three days) distorts trends
    date_sub(date_add(date_trunc(first_visits.first_seen_date, month), interval 1 month), interval 1 day)
        <= date_sub(data_window.last_date, interval 90 day) as is_complete_cohort_month,
    value_windows.revenue_first_visit,
    value_windows.revenue_7d,
    value_windows.revenue_30d,
    value_windows.revenue_60d,
    value_windows.revenue_90d,
    value_windows.orders_90d
from first_visits
inner join value_windows using (visitor_id)
cross join data_window
