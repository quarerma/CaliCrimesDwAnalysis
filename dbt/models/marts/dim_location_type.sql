-- Location-type dimension. Grain: one row per kind of place (218 rows), plus an
-- explicit UNKNOWN member.
--
-- location_description is pulled out of dim_location into its own dimension
-- because it is INDEPENDENT of the administrative geography: any block can host a
-- crime on a STREET, in an APARTMENT, or on a SIDEWALK. Cramming independent
-- attributes into one dimension multiplies them into a cross-product -- which is
-- exactly why dim_location already sits at 84,501 rows rather than the ~2,400 its
-- administrative attributes alone would need.
--
-- 'OTHER' IS NOT 'UNKNOWN'. The source has a real 'OTHER' category (269,917
-- crimes) meaning "a place that fits none of the listed types". That is a
-- recorded answer. Missing data -- location_description NULL, 16,283 crimes -- is
-- a different thing and gets the unknown member below. Collapsing the two would
-- overstate 'OTHER' and quietly hide the gap.

with observed as (
    select distinct location_description
    from {{ ref('stg_crimes') }}
    where location_description is not null
)

select
    md5(location_description)   as location_type_key,
    location_description        as location_type,
    false                       as is_unknown
from observed

union all

-- Unknown member. Sentinel rather than md5('UNKNOWN') because no such value
-- exists in the source today -- but if Chicago ever adds one, a natural-value
-- hash would silently collide with it. The double underscores cannot.
select
    md5('__UNKNOWN__')          as location_type_key,
    null                        as location_type,
    true                        as is_unknown
