-- Design Ref: §4.1 — staging 레이어: 원천 1:1 매핑, 컬럼 rename만 허용
with source as (
    select * from {{ source('jaffle_shop', 'raw_customers') }}
),

renamed as (
    select
        id          as customer_id,
        first_name,
        last_name
    from source
)

select * from renamed
