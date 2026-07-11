-- Location dimension. Grain: one row per distinct combination of the
-- administrative / location-type attributes of a crime.

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
    beat,
    district,
    ward,
    community_area,
    location_description
from distinct_locations
