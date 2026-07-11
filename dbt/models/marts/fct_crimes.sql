-- TRANSACTION FACT. Grain: one row per reported crime.
--
-- Six foreign keys: dim_date, dim_time_of_day, dim_crime_type, dim_location
-- (administrative geography), dim_location_type (kind of place) and dim_block.
--
-- case_number is a true DEGENERATE DIMENSION: it is unique per crime, so it sits
-- on the fact with no dimension table -- there is nothing to normalise out of an
-- identifier that never repeats. Contrast block, which repeats ~130 times on
-- average and therefore earned a dimension of its own.
--
-- arrest / domestic are boolean facts; is_crime is a constant 1 counter, the
-- classic idiom for a fact whose only real measure is its own occurrence.
--
-- Surrogate keys are computed from macros (macros/dw_keys.sql), NOT written out
-- inline. A hash key must be byte-identical here and in the dimension that
-- defines it, or every FK silently stops matching.

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
   + extract(minute from c.crime_date))::int         as time_key,

    md5(c.iucr)                                      as crime_type_key,

    -- Administrative geography only. Place type is a SEPARATE dimension -- the
    -- two are independent, and combining them cross-produced dim_location to
    -- 84,501 rows when 2,446 would do.
    {{ location_key('c.beat', 'c.district', 'c.ward', 'c.community_area') }}
                                                     as location_key,

    {{ location_type_key('c.location_description') }} as location_type_key,

    md5(c.block)                                     as block_key,

    -- degenerate / measures
    c.arrest,
    c.domestic,
    c.latitude,
    c.longitude,
    1                                                as is_crime
from crimes c
