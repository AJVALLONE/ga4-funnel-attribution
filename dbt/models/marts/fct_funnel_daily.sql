-- The shopping funnel by day, device and channel.
-- Grain: one row per session_date + device_category + channel.
select
    concat(
        cast(session_date as string), '|', coalesce(device_category, 'unknown'), '|', channel
    )                                                        as funnel_key,
    session_date,
    coalesce(device_category, 'unknown')                     as device_category,
    channel,
    count(*)                                                 as sessions,
    count(distinct user_pseudo_id)                           as users,
    countif(viewed_item)                                     as view_item_sessions,
    countif(added_to_cart)                                   as add_to_cart_sessions,
    countif(began_checkout)                                  as begin_checkout_sessions,
    countif(purchased)                                       as purchase_sessions,
    sum(purchases)                                           as purchases,
    sum(revenue)                                             as revenue,
    {{ safe_divide('countif(purchased)', 'count(*)') }}      as session_conversion_rate
from {{ ref('int_ga4__sessions') }}
group by 1, 2, 3, 4
