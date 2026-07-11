-- Cleaned, typed 1:1 view over orm.crimes.
-- Light standardisation only (trim, upper-case categoricals, surrogate date key);
-- no business logic. Downstream marts build the star schema from this.

with source as (
    select * from {{ source('orm', 'crimes') }}
),

renamed as (
    select
        id::bigint                                   as crime_id,
        nullif(trim(case_number), '')                as case_number,
        crime_date,
        nullif(trim(block), '')                      as block,
        nullif(trim(iucr), '')                       as iucr,
        upper(nullif(trim(primary_type), ''))        as primary_type,
        upper(nullif(trim(description), ''))         as description,
        upper(nullif(trim(location_description), '')) as location_description,
        arrest,
        domestic,
        nullif(trim(beat), '')                       as beat,
        nullif(trim(district), '')                   as district,
        ward,
        community_area,
        nullif(trim(fbi_code), '')                   as fbi_code,
        x_coordinate,
        y_coordinate,
        year,
        updated_on,
        latitude,
        longitude,
        -- YYYYMMDD integer surrogate key for the date dimension
        (extract(year  from crime_date) * 10000
       + extract(month from crime_date) * 100
       + extract(day   from crime_date))::int        as date_key
    from source
    where crime_date is not null
)

select * from renamed
