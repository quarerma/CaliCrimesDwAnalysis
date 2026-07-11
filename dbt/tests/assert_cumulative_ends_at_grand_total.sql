-- The running total, read at the final month of each crime type, must equal that
-- crime type's all-time count in the atomic fact. This proves the window frame
-- and the dense scaffold are both correct: an off-by-one frame or a scaffold that
-- dropped months would show up here. Returns rows only on failure.

with final_month as (
    select max(month_key) as month_key
    from {{ ref('fct_crime_types_cumulative') }}
),

cumulative_final as (
    select
        c.crime_type_key,
        c.cumulative_crime_count
    from {{ ref('fct_crime_types_cumulative') }} c
    join final_month f on f.month_key = c.month_key
),

atomic_by_type as (
    select
        crime_type_key,
        count(*) as crime_count
    from {{ ref('fct_crimes') }}
    group by crime_type_key
)

select
    coalesce(c.crime_type_key, a.crime_type_key) as crime_type_key,
    c.cumulative_crime_count,
    a.crime_count
from cumulative_final c
full outer join atomic_by_type a
    on a.crime_type_key = c.crime_type_key
where coalesce(c.cumulative_crime_count, 0) <> coalesce(a.crime_count, 0)
