-- Date dimension, one row per calendar day that appears in the data.
-- Grain: date_key (YYYYMMDD).

with dates as (
    select distinct
        date_key,
        crime_date::date as full_date
    from {{ ref('stg_crimes') }}
)

select
    date_key,
    full_date,
    extract(year    from full_date)::int      as year,
    extract(quarter from full_date)::int      as quarter,
    extract(month   from full_date)::int      as month,
    trim(to_char(full_date, 'Month'))         as month_name,
    extract(day     from full_date)::int      as day_of_month,
    extract(isodow  from full_date)::int      as day_of_week,
    trim(to_char(full_date, 'Day'))           as day_name,
    (extract(isodow from full_date) in (6, 7)) as is_weekend
from dates
