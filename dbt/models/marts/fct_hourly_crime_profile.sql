-- AGGREGATE FACT (temporal profile). Rebuilt with the rest of the star.
--
-- Grain: one row per (hour of day, day of week, crime type).
--
-- NOT a periodic snapshot. The other two monthly facts advance through time --
-- each row is a distinct month. This one COLLAPSES time: it pools all 25 years
-- into a single 24 x 7 profile answering "what does a typical Tuesday at 3am look
-- like". That makes it a behavioural profile, not a time series, and the two must
-- not be read the same way. There is no trend here to plot -- only a shape.
--
-- Tiny (~67k rows max: 24 hours x 7 days x ~400 IUCR codes), which is why it can
-- afford full IUCR grain rather than the category rollup the geographic snapshot
-- needs.
--
-- day_of_week / day_name are carried as plain CONFORMED ATTRIBUTES rolled up from
-- dim_date, not as an FK. A 7-row dim_day_of_week would add a join and carry no
-- attribute beyond the name itself. Contrast dim_hour, which does get a table --
-- it carries day_part and the midnight data-quality flag.
--
-- READ THIS BEFORE USING IT: hour 0 is inflated. Reports with an unknown time
-- default to 00:00, so midnight holds ~503k crimes against ~493k for the true
-- busiest hour. Join dim_hour and filter `not is_midnight_default`, or the
-- headline finding will be an artifact of missing data.
--
-- All measures are additive counts.

with crimes as (
    select
        c.time_key,
        c.crime_type_key,
        c.arrest,
        c.domestic,
        d.day_of_week,
        d.day_name
    from {{ ref('fct_crimes') }} c
    join {{ ref('dim_date') }} d
        on d.date_key = c.date_key
)

select
    -- foreign keys
    (time_key / 100)                    as hour_key,          -- HHMM -> HH
    crime_type_key,

    -- conformed attributes rolled up from dim_date
    day_of_week,
    day_name,

    -- measures (all additive)
    count(*)                            as crime_count,
    count(*) filter (where arrest)      as arrest_count,
    count(*) filter (where domestic)    as domestic_count

from crimes
group by 1, 2, 3, 4
