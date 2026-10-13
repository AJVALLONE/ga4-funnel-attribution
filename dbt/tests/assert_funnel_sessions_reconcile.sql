-- Sessions in the funnel mart must equal sessions in the sessions model.
with sessions as (
    select count(*) as n from {{ ref('int_ga4__sessions') }}
),
funnel as (
    select sum(sessions) as n from {{ ref('fct_funnel_daily') }}
)
select s.n as session_count, f.n as funnel_count
from sessions as s
cross join funnel as f
where s.n != f.n
