-- Every attribution model must hand out exactly 100% of purchases and revenue:
-- no conversion double-counted, none dropped. Any rows returned = failure.
with expected as (
    select sum(purchases) as purchases, sum(revenue) as revenue
    from {{ ref('int_ga4__sessions') }}
    where purchased
),

actual as (
    select model, sum(attributed_purchases) as purchases, sum(attributed_revenue) as revenue
    from {{ ref('fct_channel_attribution') }}
    group by model
)

select
    a.model,
    a.purchases as attributed_purchases,
    e.purchases as expected_purchases,
    a.revenue   as attributed_revenue,
    e.revenue   as expected_revenue
from actual as a
cross join expected as e
where abs(a.purchases - e.purchases) > 0.001
   or abs(a.revenue - e.revenue) > 0.01
