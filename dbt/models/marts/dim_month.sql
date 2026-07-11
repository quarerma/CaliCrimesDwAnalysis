-- Month dimension. Grain: one row per calendar month present in the data.
--
-- This is a SHRUNKEN CONFORMED DIMENSION: a rollup of dim_date to month grain.
-- It is built from dim_date (not from stg_crimes) on purpose -- deriving it from
-- the daily dimension guarantees the labels here are identical to the ones
-- there. That is what makes the monthly aggregate fact safely drillable against
-- the atomic fct_crimes: both agree on what "March 2015" means.

with months as (
    select distinct
        year,
        quarter,
        month,
        month_name
    from {{ ref('dim_date') }}
)

select
    -- YYYYMM integer surrogate key, mirroring dim_date's YYYYMMDD convention.
    -- The fact derives it as date_key / 100, which is exact integer division.
    (year * 100 + month)          as month_key,

    -- First calendar day of the month: the anchor date BI tools want for a
    -- proper time axis (Power BI cannot build a date hierarchy off an int).
    make_date(year, month, 1)     as first_day_of_month,

    year,
    quarter,
    month,
    month_name
from months
