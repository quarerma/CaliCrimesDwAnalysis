-- Time-of-day dimension. Grain: one row per minute of the day (1440 rows).
--
-- SEPARATE FROM dim_date ON PURPOSE. Date and time-of-day are always modelled as
-- two dimensions, never one: a combined date+time dimension at minute grain would
-- be ~306 months x 1440 minutes = ~13M rows, larger than most of the star. Split,
-- they are 306 and 1440 rows, and fct_crimes simply carries both keys. This also
-- lets you ask "crime by hour, across all years" -- a question a combined
-- dimension makes awkward.
--
-- GENERATED, NOT DERIVED. Unlike dim_date (which is built from observed crime
-- dates), this is a complete spine of all 1440 minutes whether or not a crime
-- happened in each. A time dimension with holes would silently drop empty minutes
-- out of hour-by-hour rollups.
--
-- Minute grain rather than hour: it costs nothing at 1440 rows and rolls up to
-- hour or day_part freely. The reverse is not true.

with minutes as (
    select generate_series(0, 1439) as minute_of_day
)

select
    -- HHMM integer surrogate key (0 .. 2359), mirroring the YYYYMMDD / YYYYMM
    -- convention used by dim_date and dim_month. 08:35 -> 835.
    ((minute_of_day / 60) * 100 + (minute_of_day % 60))       as time_key,

    (minute_of_day / 60)                                      as hour_24,
    (minute_of_day % 60)                                      as minute,

    -- Zero-padded label for axis display, e.g. "08:35".
    lpad((minute_of_day / 60)::text, 2, '0') || ':' ||
    lpad((minute_of_day % 60)::text, 2, '0')                  as time_label,

    -- 12-hour clock, for report readability.
    case
        when (minute_of_day / 60) = 0  then 12
        when (minute_of_day / 60) > 12 then (minute_of_day / 60) - 12
        else (minute_of_day / 60)
    end                                                       as hour_12,
    case when (minute_of_day / 60) < 12 then 'AM' else 'PM' end as am_pm,

    -- Coarse buckets: usually the attribute you actually want to slice by, since
    -- 24 separate hours is too granular to read in most visuals.
    case
        when (minute_of_day / 60) between  0 and  5 then 'LATE NIGHT'
        when (minute_of_day / 60) between  6 and 11 then 'MORNING'
        when (minute_of_day / 60) between 12 and 17 then 'AFTERNOON'
        else                                             'EVENING'
    end                                                       as day_part,

    -- DATA QUALITY FLAG, not a real attribute. Midnight is by far the most common
    -- timestamp in the source (~503k crimes, vs ~493k for the next-highest hour)
    -- because reports with an unknown time default to 00:00. That spike is an
    -- artifact, not a crime wave. Filter on this flag before drawing any
    -- conclusion about overnight crime.
    (minute_of_day = 0)                                       as is_midnight_default

from minutes
