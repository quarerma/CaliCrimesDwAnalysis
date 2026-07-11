-- Crime-category dimension. Grain: one row per primary_type (34 rows).
--
-- SHRUNKEN CONFORMED DIMENSION: a rollup of dim_crime_type from IUCR grain (~400
-- codes) to category grain (34). Built FROM dim_crime_type, not from staging, so
-- the two can never disagree about which category an IUCR belongs to.
--
-- This exists to make fct_monthly_area_crimes a worthwhile aggregate. At IUCR
-- grain that snapshot would be ~1.35M rows -- only 6x smaller than the 8.6M-row
-- atomic fact, which is a poor return for a rollup. At category grain it is
-- ~384k rows, 22x smaller, and category is the level people actually ask
-- questions at ("is violent crime rising here?").

with categories as (
    select distinct primary_type
    from {{ ref('dim_crime_type') }}
    where primary_type is not null
)

select
    md5(primary_type)   as crime_category_key,
    primary_type
from categories
