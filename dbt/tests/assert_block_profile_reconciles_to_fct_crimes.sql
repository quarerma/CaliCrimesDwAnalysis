-- The block profile must account for every crime. This is also what proves the
-- location-type unknown member is working: 16,283 crimes have a NULL
-- location_description, and if they were dropped rather than routed to the
-- unknown member, this fails. Returns rows only on failure.

with profile_total as (
    select sum(crime_count) as n from {{ ref('fct_block_location_profile') }}
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
