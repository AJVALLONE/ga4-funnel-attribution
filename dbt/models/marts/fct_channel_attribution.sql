-- Purchases and revenue credited to each channel under three attribution models.
-- Grain: one row per model + channel.
with paths as (
    select * from {{ ref('int_ga4__conversion_paths') }}
),

conversions as (
    select distinct conversion_session_key, purchases, revenue
    from paths
),

last_non_direct as (
    -- GA4-style last click: the last touch that wasn't Direct. All-Direct paths stay Direct.
    select
        conversion_session_key,
        coalesce(
            array_agg(
                if(channel != 'Direct', channel, null)
                ignore nulls order by touch_number desc limit 1
            )[safe_offset(0)],
            'Direct'
        ) as channel
    from paths
    group by conversion_session_key
),

credits as (
    select 'first_touch' as model, channel, conversion_session_key, 1.0 as credit
    from paths
    where touch_number = 1

    union all

    select 'last_non_direct_touch' as model, channel, conversion_session_key, 1.0 as credit
    from last_non_direct

    union all

    select 'linear' as model, channel, conversion_session_key, 1.0 / path_length as credit
    from paths
)

select
    concat(cr.model, '|', cr.channel)          as model_channel_key,
    cr.model,
    cr.channel,
    sum(cr.credit * cv.purchases)              as attributed_purchases,
    sum(cr.credit * cv.revenue)                as attributed_revenue
from credits as cr
inner join conversions as cv
    on cr.conversion_session_key = cv.conversion_session_key
group by cr.model, cr.channel
