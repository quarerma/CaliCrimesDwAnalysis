-- Community-area dimension. Grain: one row per community area, plus an
-- explicit UNKNOWN member.
--
-- Chicago's community areas are numbered 1-77 and their boundaries are stable
-- over the whole 2001-present span -- which makes this the only geography in the
-- source safe for long-run trend analysis (wards are redrawn each census, see
-- dim_location).
--
-- TWO KINDS OF MISSING, both flagged by is_unknown:
--   key -1  community_area was NULL in the source (~614k crimes, 7.1%)
--   key  0  community_area was 0, which is not a real area -- 1-77 are the only
--           valid codes, so 0 is a source placeholder for "not assigned"
-- The UNKNOWN MEMBER (-1) is the standard Kimball device for this: rather than
-- letting the fact carry a NULL FK (which silently drops rows from inner joins
-- and makes totals disagree), every fact row points at a real dimension row, and
-- the unassigned ones point here. That is why fct_monthly_area_crimes can have a
-- not_null FK and still reconcile exactly to fct_crimes.
--
-- NO POPULATION COLUMN, and that is the single most important limitation of this
-- whole model. Without it every geographic measure is a raw count, and a raw
-- count ranks areas by how BUSY they are, not how DANGEROUS they are. Treat
-- "community area with the most crimes" as a TRAP METRIC. Until population is
-- available, normalise within the data instead -- compare an area's crime MIX
-- (share violent, share property) rather than its volume.

with observed as (
    select distinct community_area
    from {{ ref('stg_crimes') }}
    where community_area is not null
)

select
    community_area::int          as community_area_key,
    community_area::int          as community_area,
    (community_area = 0)         as is_unknown
from observed

union all

-- Unknown member: the landing spot for source NULLs.
select
    -1                           as community_area_key,
    null::int                    as community_area,
    true                         as is_unknown
