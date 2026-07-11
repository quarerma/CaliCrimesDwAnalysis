-- Crime-type dimension. Grain: one row per IUCR code.
--
-- An IUCR code can carry more than one label in the source, because Chicago has
-- RENAMED categories over the 2001-present span. 13 of the 418 codes are
-- affected, all of them sexual-assault codes (0261-0291): "CRIM SEXUAL ASSAULT"
-- was retired around 2020 and replaced by "CRIMINAL SEXUAL ASSAULT". Both labels
-- exist in the data for the same code.
--
-- The dedup below therefore ranks by MOST RECENTLY USED, not by most frequent.
-- Ranking by count(*) would let the retired label win on historical volume
-- (e.g. IUCR 0281: 15,282 old-label crimes vs 8,660 new-label), and every crime
-- from 2021 onward would be reported under a name Chicago no longer uses.
-- Recency picks the current name; count(*) desc remains as the tiebreak.
--
-- Safe here because the only ambiguity in the data is this one clean rename --
-- there are no stray or typo labels that a recency rule could wrongly promote.
-- This is a Type 1 (overwrite) treatment: history is relabelled to the current
-- name rather than preserved. If the historical label ever matters, this becomes
-- a Type 2 SCD instead.

with ranked as (
    select
        iucr,
        primary_type,
        description,
        fbi_code,
        count(*)         as n,
        max(crime_date)  as last_seen,
        row_number() over (
            partition by iucr
            order by max(crime_date) desc, count(*) desc, primary_type, description
        ) as rn
    from {{ ref('stg_crimes') }}
    where iucr is not null
    group by iucr, primary_type, description, fbi_code
)

select
    md5(iucr)     as crime_type_key,
    iucr,
    primary_type,
    description,
    fbi_code
from ranked
where rn = 1
