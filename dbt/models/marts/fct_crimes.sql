-- Crimes fact. Grain: one row per reported crime.
-- Foreign keys reference dim_date, dim_crime_type, dim_location and dim_block;
-- arrest / domestic are degenerate boolean facts, plus a constant is_crime
-- counter. case_number is a true degenerate dimension: it is unique per crime,
-- so there is nothing to normalise out of it.

with crimes as (
    select * from {{ ref('stg_crimes') }}
)

select
    c.crime_id,
    c.case_number,
    c.crime_date,

    -- foreign keys
    c.date_key,

    -- HHMM time-of-day key. Split out from crime_date so the time component is
    -- analysable; crime_date itself is kept above as the full audit timestamp.
    (extract(hour   from c.crime_date) * 100
   + extract(minute from c.crime_date))::int as time_key,

    md5(c.iucr)                          as crime_type_key,
    md5(
        coalesce(c.beat, '')             || '|' ||
        coalesce(c.district, '')         || '|' ||
        coalesce(c.ward::text, '')       || '|' ||
        coalesce(c.community_area::text, '') || '|' ||
        coalesce(c.location_description, '')
    )                                    as location_key,
    md5(c.block)                         as block_key,

    -- degenerate / measures
    c.arrest,
    c.domestic,
    c.latitude,
    c.longitude,
    1                                    as is_crime
from crimes c
