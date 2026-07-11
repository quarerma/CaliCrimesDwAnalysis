-- Grain test: (month_key, crime_type_key) must be unique in the periodic
-- snapshot. A singular test rather than dbt_utils' unique_combination_of_columns
-- so the project stays dependency-free. Returns rows only on failure.

select
    month_key,
    crime_type_key,
    count(*) as n
from {{ ref('fct_monthly_crime_types') }}
group by month_key, crime_type_key
having count(*) > 1
