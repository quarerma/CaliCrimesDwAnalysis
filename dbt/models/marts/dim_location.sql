-- Location dimension. Grain: one row per distinct combination of the
-- administrative / location-type attributes of a crime.
--
-- The four administrative attributes are overlapping but NOT nested geographies:
-- police beats/districts, political wards and statistical community areas are
-- drawn by different bodies and their boundaries cross each other.

with distinct_locations as (
    select distinct
        beat,
        district,
        ward,
        community_area,
        location_description
    from {{ ref('stg_crimes') }}
)

select
    md5(
        coalesce(beat, '')             || '|' ||
        coalesce(district, '')         || '|' ||
        coalesce(ward::text, '')       || '|' ||
        coalesce(community_area::text, '') || '|' ||
        coalesce(location_description, '')
    )                       as location_key,

    -- Smallest police geography: the area covered by a single patrol car.
    -- Beats group into sectors, sectors into districts.
    beat,

    -- Police district (precinct) the beat belongs to; ~22 across the city.
    district,

    -- City Council ward: the political geography, one elected alderman each
    -- (~50). Redrawn after each census, so it is not stable over the full
    -- 2001-present span of this dataset.
    ward,

    -- One of Chicago's 77 official community areas: the stable statistical
    -- geography used for most demographic reporting. Unlike wards, boundaries
    -- have essentially not changed, which makes this the safest attribute for
    -- long-run trend analysis.
    community_area,

    -- Type of place the incident occurred, not where: STREET, APARTMENT,
    -- SIDEWALK, etc. Free-text-ish in the source, upper-cased in staging.
    location_description

from distinct_locations
