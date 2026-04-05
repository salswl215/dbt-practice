-- Design Ref: §4.1 — staging 레이어: 원천 1:1 매핑, status 정제
with source as (
    select * from {{ source('jaffle_shop', 'raw_orders') }}
),

renamed as (
    select
        id          as order_id,
        user_id     as customer_id,
        order_date,
        status
    from source
)

select * from renamed
