-- Crimes fact. Grain: one row per reported crime.
-- Foreign keys reference dim_date, dim_crime_type and dim_location; arrest /
-- domestic are degenerate boolean facts, plus a constant is_crime counter.

with crimes as (
    select * from {{ ref('stg_crimes') }}
)

select
    c.crime_id,
    c.case_number,
    c.crime_date,

    -- foreign keys
    c.date_key,
    md5(c.iucr)                          as crime_type_key,
    md5(
        coalesce(c.beat, '')             || '|' ||
        coalesce(c.district, '')         || '|' ||
        coalesce(c.ward::text, '')       || '|' ||
        coalesce(c.community_area::text, '') || '|' ||
        coalesce(c.location_description, '')
    )                                    as location_key,

    -- degenerate / measures
    c.arrest,
    c.domestic,
    c.block,
    c.latitude,
    c.longitude,
    1                                    as is_crime
from crimes c
