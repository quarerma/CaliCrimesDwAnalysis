-- AGGREGATE FACT (compositional profile).
-- Grain: one row per (block, location type).
--
-- WHY THIS EXISTS INSTEAD OF A dim_block.location_type ATTRIBUTE.
-- The obvious move is to label each block with its dominant location type. The
-- data says don't. Across 65,063 blocks the modal location type accounts for
-- 52.6% of that block's crimes on average -- which sounds like blocks have a
-- clear character. But restrict to blocks with real volume (>=100 crimes) and the
-- modal share collapses to 36.2%. The 52.6% is propped up by tiny blocks: a block
-- with two crimes, both on the STREET, scores a perfect 100% on nothing. The
-- metric looks strongest exactly where it knows the least -- a textbook TRAP
-- METRIC.
--
-- Concretely, the busiest block in the city (001XX N STATE ST) is 54.5%
-- DEPARTMENT STORE -- but also 11.3% small retail, 7.7% CTA platform, 4.7% CTA
-- train, 4.1% restaurant. Labelling it "DEPARTMENT STORE" is the modal answer and
-- an analytically useless one: it is a retail AND transit corridor, and the
-- transit half is the interesting part. This is structural, not a quirk -- a
-- Chicago block is ~1/8 mile of city containing homes, streets, sidewalks and
-- storefronts. There is no single type, and forcing one destroys the signal.
--
-- So: keep the whole distribution, and let the analyst ask what share of a block
-- is what.
--
-- THIS IS ALSO THE ANSWER TO THE MISSING POPULATION. Raw counts rank blocks by
-- how BUSY they are, not how DANGEROUS -- and with no population column in this
-- source, that trap cannot be escaped by normalising against residents. But a
-- block's crime MIX does not depend on how busy the block is. Composition is
-- SELF-NORMALISING. "Which blocks have an unusually violent mix" is a question
-- this table can answer honestly; "which block is most dangerous" is not.
--
-- ADDITIVITY -- read before aggregating:
--   crime_count        ADDITIVE. Safe to sum anywhere.
--   block_crime_count  NOT ADDITIVE. It is the block's total, repeated on every
--                      row of that block. Summing it multiplies the block's total
--                      by its number of location types. Use max(), or divide.
--   share_of_block     SEMI-ADDITIVE. Sums to exactly 1.0 across the location
--                      types WITHIN one block (a test asserts this). Meaningless
--                      summed across blocks.

with counted as (
    -- location_type_key is read straight off the fact -- no join to dim_location
    -- needed since place type became its own dimension. NULL location_description
    -- was already routed to the unknown member upstream, so this reconciles to
    -- fct_crimes with nothing dropped.
    select
        block_key,
        location_type_key,
        count(*) as crime_count
    from {{ ref('fct_crimes') }}
    group by 1, 2
)

select
    -- foreign keys
    block_key,
    location_type_key,

    -- additive measure
    crime_count,

    -- denominator, repeated per row. NOT additive -- see header.
    sum(crime_count) over (partition by block_key)              as block_crime_count,

    -- this location type's share of the block's crimes. Semi-additive: sums to
    -- 1.0 within a block, meaningless across blocks.
    round(
        crime_count::numeric / sum(crime_count) over (partition by block_key),
        6
    )                                                           as share_of_block

from counted
