-- One row per first channel, cohort month and number of days since the first
-- visit (0 means the first visit alone). The same numbers as
-- visitor_value_by_channel, turned from five columns into five rows, so a chart
-- can put the days on its x-axis. Revenue is cumulative up to that day.
select
    concat(
        mart.first_channel, ' | ', cast(mart.cohort_month as string),
        ' | ', cast(points.days_since_first_visit as string)
    ) as curve_key,
    mart.first_channel,
    mart.cohort_month,
    mart.is_complete_month,
    points.days_since_first_visit,
    mart.new_visitors,
    points.cumulative_revenue
from {{ ref('visitor_value_by_channel') }} as mart
cross join unnest([
    struct(0 as days_since_first_visit, mart.revenue_first_visit as cumulative_revenue),
    struct(7, mart.revenue_7d),
    struct(30, mart.revenue_30d),
    struct(60, mart.revenue_60d),
    struct(90, mart.revenue_90d)
]) as points
