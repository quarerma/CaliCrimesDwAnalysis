-- PERIODIC SNAPSHOT FACT -- refreshed at the end of each month.
--
-- Grain: one row per (month, community area, crime category).
--
-- The geographic counterpart to fct_monthly_crime_types: that one answers "which
-- crimes are rising", this one answers "WHERE are they rising". Rolled up from
-- fct_crimes so the two can never disagree with the atomic fact or each other.
--
-- Community area rather than block or ward, deliberately:
--   * ward boundaries are redrawn each census, so a ward trend line spanning
--     2001-present is comparing different pieces of ground to each other
--   * block is far too fine for a trend (66k blocks x 306 months is a bigger
--     table than the fact it summarises, and most cells would be noise)
--   * community-area boundaries have been stable for decades -- the only
--     geography here that supports an honest long-run trend
--
-- Crime CATEGORY (34) rather than IUCR (~400): at IUCR grain this table is 1.35M
-- rows, only 6x smaller than the atomic fact -- a poor return for a rollup. At
-- category grain it is ~384k, and category is the level the questions are
-- actually asked at.
--
-- TRAP METRIC WARNING. crime_count here is a RAW COUNT, and community areas
-- differ enormously in size and footfall. Ranking areas by crime_count ranks them
-- by how BUSY they are, not how DANGEROUS they are -- the Loop will always look
-- terrible because a quarter of a million people go there every day. This model
-- has no population column and cannot have one from this source (see
-- dim_community_area). Until it does, compare an area's crime MIX -- violent as a
-- share of that area's own total -- rather than its volume. Composition is
-- self-normalising; counts are not.
--
-- All measures are additive counts. No rate columns: a rate cannot be summed.

with crimes as (
    select
        c.date_key,
        c.crime_type_key,
        c.arrest,
        c.domestic,
        l.community_area
    from {{ ref('fct_crimes') }} c
    join {{ ref('dim_location') }} l
        on l.location_key = c.location_key
),

categorised as (
    select
        (cr.date_key / 100)                     as month_key,   -- YYYYMMDD -> YYYYMM
        -- Source NULLs land on the unknown member (-1) rather than becoming a
        -- NULL FK, so this table still reconciles exactly to fct_crimes.
        coalesce(cr.community_area, -1)         as community_area_key,
        md5(t.primary_type)                     as crime_category_key,
        cr.arrest,
        cr.domestic
    from crimes cr
    join {{ ref('dim_crime_type') }} t
        on t.crime_type_key = cr.crime_type_key
)

select
    -- foreign keys
    month_key,
    community_area_key,
    crime_category_key,

    -- measures (all additive)
    count(*)                            as crime_count,
    count(*) filter (where arrest)      as arrest_count,
    count(*) filter (where domestic)    as domestic_count

from categorised
group by 1, 2, 3
