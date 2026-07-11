-- The geographic snapshot must lose nothing. This is the test that proves the
-- unknown member (-1) is doing its job: ~614k crimes have a NULL community_area,
-- and if they were dropped instead of routed to the unknown member, this fails.
-- Returns rows only on failure.

with snapshot_total as (
    select sum(crime_count) as n from {{ ref('fct_monthly_area_crimes') }}
),

atomic_total as (
    select count(*) as n from {{ ref('fct_crimes') }}
)

select
    s.n as snapshot_crimes,
    a.n as atomic_crimes
from snapshot_total s
cross join atomic_total a
where s.n <> a.n
