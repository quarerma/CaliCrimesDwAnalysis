-- share_of_block must sum to exactly 1.0 across the location types within each
-- block. If the window partition or the unknown-member coalesce were ever broken,
-- a block's shares would stop summing to 1 and every composition metric built on
-- this table would be quietly wrong.
--
-- Tolerance of 1e-4 absorbs the round(..., 6) applied to each row -- a block with
-- many location types accumulates a little rounding dust, which is expected.
-- Returns rows only on failure.

with per_block as (
    select
        block_key,
        sum(share_of_block) as total_share
    from {{ ref('fct_block_location_profile') }}
    group by block_key
)

select
    block_key,
    total_share
from per_block
where abs(total_share - 1.0) > 0.0001
