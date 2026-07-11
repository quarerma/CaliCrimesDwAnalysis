-- Crime-type dimension. Grain: one row per IUCR code.
-- primary_type / description / fbi_code are taken as the most frequent
-- value seen for each IUCR code (they are stable in practice).

with ranked as (
    select
        iucr,
        primary_type,
        description,
        fbi_code,
        count(*) as n,
        row_number() over (
            partition by iucr
            order by count(*) desc, primary_type, description
        ) as rn
    from {{ ref('stg_crimes') }}
    where iucr is not null
    group by iucr, primary_type, description, fbi_code
)

select
    md5(iucr)     as crime_type_key,
    iucr,
    primary_type,
    description,
    fbi_code
from ranked
where rn = 1
