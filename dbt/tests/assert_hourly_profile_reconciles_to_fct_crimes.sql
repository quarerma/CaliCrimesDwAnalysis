-- The hourly profile pools every crime into a 24x7 grid; nothing may fall out.
-- Returns rows only on failure.

with profile_total as (
    select sum(crime_count) as n from {{ ref('fct_hourly_crime_profile') }}
),

atomic_total as (
    select count(*) as n from {{ ref('fct_crimes') }}
)

select
    p.n as profile_crimes,
    a.n as atomic_crimes
from profile_total p
cross join atomic_total a
where p.n <> a.n
