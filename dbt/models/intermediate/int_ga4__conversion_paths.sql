-- For every session with a purchase, list every session the same visitor had in the
-- lookback window up to and including it. These are the "touches" attribution credits.
with sessions as (
    select * from {{ ref('int_ga4__sessions') }}
),

conversions as (
    select
        session_key        as conversion_session_key,
        user_pseudo_id,
        session_start_at   as converted_at,
        session_date       as conversion_date,
        purchases,
        revenue
    from sessions
    where purchased
),

touches as (
    select
        c.*,
        s.session_key       as touch_session_key,
        s.session_start_at  as touch_at,
        s.channel
    from conversions as c
    inner join sessions as s
        on s.user_pseudo_id = c.user_pseudo_id
        and s.session_start_at <= c.converted_at
        and s.session_start_at >= timestamp_sub(
            c.converted_at, interval {{ var('lookback_days') }} day
        )
)

select
    *,
    row_number() over (
        partition by conversion_session_key order by touch_at, touch_session_key
    ) as touch_number,
    count(*) over (partition by conversion_session_key) as path_length
from touches
