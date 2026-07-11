-- Hour dimension. Grain: one row per hour of the day (24 rows).
--
-- SHRUNKEN CONFORMED DIMENSION: a rollup of dim_time_of_day from minute grain
-- (1440) to hour grain (24), exactly as dim_month is a rollup of dim_date. Built
-- from dim_time_of_day so day_part and the midnight flag are guaranteed to mean
-- the same thing in both.
--
-- It earns its own table because it carries real attributes -- day_part and the
-- is_midnight_default data-quality flag. Contrast day_of_week in
-- fct_hourly_crime_profile, which is left as a plain conformed attribute: its
-- only payload is its own name, so a 7-row dimension would add a join and carry
-- nothing.

with hours as (
    select distinct
        hour_24,
        day_part,
        is_midnight_default
    from {{ ref('dim_time_of_day') }}
    where minute = 0
)

select
    hour_24              as hour_key,
    hour_24,
    day_part,

    -- True for hour 0 only. Reports with an unknown time default to 00:00, so
    -- midnight is the most common hour in the data by a wide margin. That is an
    -- artifact, not an overnight crime wave -- exclude it before concluding
    -- anything about late-night crime.
    is_midnight_default,

    lpad(hour_24::text, 2, '0') || ':00'   as hour_label
from hours
