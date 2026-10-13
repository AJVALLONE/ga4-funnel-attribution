-- One row per GA4 event, with the nested fields we need pulled out into flat columns.
-- This is the only model that reads the raw public data, so it's the only one that
-- costs real query bytes. Everything downstream reads this smaller flat table.

select
    parse_date('%Y%m%d', event_date)                            as event_date,
    timestamp_micros(event_timestamp)                            as event_timestamp,
    event_name,
    user_pseudo_id,
    {{ ga4_param('ga_session_id', 'int') }}                      as ga_session_id,
    concat(
        user_pseudo_id, '-',
        cast({{ ga4_param('ga_session_id', 'int') }} as string)
    )                                                            as session_key,
    {{ ga4_param('page_location', 'string') }}                   as page_location,
    {{ ga4_param('source', 'string') }}                          as source,
    {{ ga4_param('medium', 'string') }}                          as medium,
    {{ ga4_param('campaign', 'string') }}                        as campaign,
    device.category                                              as device_category,
    geo.country                                                  as country,
    ecommerce.transaction_id                                     as transaction_id,
    coalesce(ecommerce.purchase_revenue_in_usd, 0)               as purchase_revenue
from {{ source('ga4', 'events') }}
where _table_suffix between '{{ var("start_date") }}' and '{{ var("end_date") }}'
