-- CUMULATIVE SNAPSHOT FACT -- rewritten in full at the end of each month.
--
-- Grain: one row per (month, crime type). Carries running totals to date.
--
-- WHY NOT "ACCUMULATING SNAPSHOT": Kimball's accumulating snapshot has one row
-- per *process instance* (one crime), with a milestone date FK per stage --
-- reported / arrested / charged / disposed -- and the row is UPDATED in place as
-- the case advances through the pipeline. The Chicago source cannot support
-- that: it carries an `arrest` boolean but no arrest DATE, and no charge or
-- disposition milestones at all. There is nothing to accumulate per case. So
-- this is a cumulative (running-total) snapshot instead: same grain as the
-- periodic snapshot, but each row answers "how many, from the beginning of the
-- data through the end of this month".
--
-- DENSE, unlike fct_monthly_crime_types. Every crime type gets a row for every
-- month, including months where it saw zero crimes. This is not optional for a
-- running total: if a quiet month were simply missing, a cumulative line chart
-- would jump the gap and misstate the shape of the curve. The scaffold below
-- (dim_month CROSS JOIN dim_crime_type) is what carries the total forward
-- through the quiet months.
--
-- ADDITIVITY -- the important part:
--   crime_count / arrest_count / domestic_count   ADDITIVE. Activity in the
--       month. Safe to sum across months and crime types.
--   cumulative_* and ytd_*                        NON-ADDITIVE across months.
--       They are already sums. Summing them again double-counts every earlier
--       month. Read a single row, filter to one month, or take max() -- never
--       sum(). They ARE safe to sum across crime types within one month.

with scaffold as (
    -- Every (month, crime type) pair, whether or not anything happened.
    select
        m.month_key,
        m.year,
        t.crime_type_key
    from {{ ref('dim_month') }} m
    cross join {{ ref('dim_crime_type') }} t
),

monthly as (
    select * from {{ ref('fct_monthly_crime_types') }}
),

densified as (
    select
        s.month_key,
        s.year,
        s.crime_type_key,
        coalesce(mo.crime_count,    0) as crime_count,
        coalesce(mo.arrest_count,   0) as arrest_count,
        coalesce(mo.domestic_count, 0) as domestic_count
    from scaffold s
    left join monthly mo
        on  mo.month_key      = s.month_key
        and mo.crime_type_key = s.crime_type_key
)

select
    -- foreign keys
    month_key,
    crime_type_key,

    -- this month's activity (additive)
    crime_count,
    arrest_count,
    domestic_count,

    -- running totals since the start of the data (non-additive across months)
    sum(crime_count)    over w_to_date as cumulative_crime_count,
    sum(arrest_count)   over w_to_date as cumulative_arrest_count,
    sum(domestic_count) over w_to_date as cumulative_domestic_count,

    -- year-to-date, resetting each January (non-additive across months)
    sum(crime_count)    over w_ytd     as ytd_crime_count,
    sum(arrest_count)   over w_ytd     as ytd_arrest_count,
    sum(domestic_count) over w_ytd     as ytd_domestic_count

from densified
window
    w_to_date as (
        partition by crime_type_key
        order by month_key
        rows between unbounded preceding and current row
    ),
    w_ytd as (
        partition by crime_type_key, year
        order by month_key
        rows between unbounded preceding and current row
    )
