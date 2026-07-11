-- Administrative-location dimension.
-- Grain: one row per distinct combination of the administrative geographies.
--
-- location_description USED TO LIVE HERE, and pulling it out is why this table
-- dropped from 84,501 rows to ~2,446. The two are INDEPENDENT: any beat can host
-- a crime on a STREET, in an APARTMENT or on a SIDEWALK. Independent attributes
-- crammed into one dimension multiply into a cross-product -- 2,446 admin
-- combinations x 218 location types was manufacturing ~82k rows of nothing. Place
-- type now has its own dimension (dim_location_type) and fct_crimes carries a
-- separate FK to it.
--
-- The four attributes below are overlapping but NOT nested geographies: police
-- beats/districts, political wards and statistical community areas are drawn by
-- different bodies and their boundaries cross each other. There is no clean
-- hierarchy to roll up, which is exactly why they sit together in one dimension
-- rather than as levels of one.

with distinct_locations as (
    select distinct
        beat,
        district,
        ward,
        community_area
    from {{ ref('stg_crimes') }}
)

select
    {{ location_key('beat', 'district', 'ward', 'community_area') }} as location_key,

    -- Smallest police geography: the area covered by a single patrol car.
    -- Beats group into sectors, sectors into districts.
    beat,

    -- Police district (precinct) the beat belongs to; ~22 across the city.
    district,

    -- City Council ward: the political geography, one elected alderman each
    -- (~50). Redrawn after each census, so it is NOT stable across the
    -- 2001-present span -- a ward trend line compares different ground to itself.
    ward,

    -- One of Chicago's 77 official community areas: the stable statistical
    -- geography used for most demographic reporting. Boundaries have essentially
    -- not changed, which makes this the only safe attribute here for long-run
    -- trend analysis. See dim_community_area.
    community_area

from distinct_locations
