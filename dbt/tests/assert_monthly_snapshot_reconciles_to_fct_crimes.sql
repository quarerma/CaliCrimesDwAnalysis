-- The whole point of a rollup is that it agrees with the atomic fact.
-- If the periodic snapshot ever drops or double-counts crimes, this catches it.
-- Returns rows only on failure.

with snapshot_total as (
    select sum(crime_count) as n from {{ ref('fct_monthly_crime_types') }}
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
