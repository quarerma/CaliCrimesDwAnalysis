-- PERIODIC SNAPSHOT FACT -- refreshed at the end of each month.
--
-- Grain: one row per (month, crime type) that occurred.
--
-- Periodic snapshot is the Kimball fact type for "state of the process over a
-- fixed, repeating interval". The measures below describe activity DURING the
-- month, not at an instant in it, and every row covers exactly one month --
-- that regular, predictable heartbeat is what makes it periodic rather than a
-- transaction fact (fct_crimes, one row per event) or a cumulative one
-- (fct_crime_types_cumulative, running totals to date).
--
-- Built from fct_crimes, not from stg_crimes, so it can never disagree with the
-- atomic fact -- if it read from staging, a filter added to fct_crimes would
-- silently make the two tables tell different stories. tests/ asserts that
-- sum(crime_count) here still equals count(*) there.
--
-- SPARSE by construction: a (month, crime type) pair with no crimes gets no row,
-- rather than a zero row. Correct for a periodic snapshot -- but it means a BI
-- line chart connects straight across an empty month instead of dropping to
-- zero. Use fct_crime_types_cumulative (which is dense) when the gap matters.
--
-- ALL MEASURES ARE ADDITIVE COUNTS, deliberately. No arrest_rate column: a rate
-- is non-additive -- summing or averaging percentages across months or crime
-- types gives the wrong answer. Store the numerator and the denominator, and let
-- the BI layer divide the *sums* at query time:
--     sum(arrest_count) / sum(crime_count)

with crimes as (
    select * from {{ ref('fct_crimes') }}
)

select
    -- foreign keys
    (date_key / 100)                            as month_key,   -- YYYYMMDD -> YYYYMM
    crime_type_key,

    -- measures (all additive)
    count(*)                                    as crime_count,
    count(*) filter (where arrest)              as arrest_count,
    count(*) filter (where domestic)            as domestic_count,

    -- distinct blocks touched by this crime type this month. NOTE: semi-additive
    -- at best -- it is safe to read per row, but summing it across months or
    -- crime types double-counts any block that appears in more than one. Do not
    -- aggregate this column further in BI.
    count(distinct block_key)                   as distinct_blocks

from crimes
group by 1, 2
