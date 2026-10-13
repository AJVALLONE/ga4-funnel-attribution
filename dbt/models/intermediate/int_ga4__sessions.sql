-- One row per session: where it came from, what the visitor did, and what they spent.
with events as (
    select *
    from {{ ref('stg_ga4__events') }}
    where ga_session_id is not null
),

sessions as (
    select
        session_key,
        any_value(user_pseudo_id)                                       as user_pseudo_id,
        min(event_timestamp)                                            as session_start_at,
        min(event_date)                                                 as session_date,

        -- Traffic source: the first event in the session that carries a source.
        -- Source, medium and campaign are taken together so they always match.
        array_agg(
            if(source is not null, struct(source, medium, campaign), null)
            ignore nulls order by event_timestamp limit 1
        )[safe_offset(0)]                                               as traffic,

        array_agg(
            if(event_name = 'page_view', page_location, null)
            ignore nulls order by event_timestamp limit 1
        )[safe_offset(0)]                                               as landing_page,

        any_value(device_category)                                      as device_category,
        any_value(country)                                              as country,

        countif(event_name = 'page_view')                               as page_views,
        logical_or(event_name = 'view_item')                            as viewed_item,
        logical_or(event_name = 'add_to_cart')                          as added_to_cart,
        logical_or(event_name = 'begin_checkout')                       as began_checkout,
        logical_or(event_name = 'purchase')                             as purchased,
        countif(event_name = 'purchase')                                as purchases,
        sum(if(event_name = 'purchase', purchase_revenue, 0))           as revenue
    from events
    group by session_key
),

with_source as (
    select
        * except (traffic),
        -- GA4 convention: no source recorded means a direct visit.
        coalesce(traffic.source, '(direct)')                            as source,
        coalesce(traffic.medium, '(none)')                              as medium,
        traffic.campaign                                                as campaign
    from sessions
)

select
    *,
    {{ channel_group('source', 'medium') }}                             as channel,
    row_number() over (
        partition by user_pseudo_id order by session_start_at, session_key
    )                                                                   as user_session_number
from with_source
