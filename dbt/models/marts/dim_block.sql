-- Block dimension. Grain: one row per distinct city block.
--
-- Chicago publishes addresses at block level with the house number partially
-- redacted (e.g. "0000X N STATE ST"), so the block is the finest geography the
-- source exposes. It is a repeating attribute -- ~66k distinct values across
-- ~8.6M crimes -- which is what makes it dimension material rather than a
-- degenerate attribute on the fact.
--
-- `block` is never null and never blank in the source, so block_key needs no
-- coalesce and the fact's FK can be not_null with no "unknown" member.
--
-- Deliberately kept to the block itself: geographic coordinates are out of
-- scope for this model. If block-level rates (rather than counts) are ever
-- needed, this is where a centroid or population attribute would land.

with distinct_blocks as (
    select distinct block
    from {{ ref('stg_crimes') }}
    where block is not null
)

select
    md5(block)  as block_key,
    block
from distinct_blocks
