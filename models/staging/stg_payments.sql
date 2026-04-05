-- Design Ref: §4.1 — staging 레이어: cents_to_dollars 매크로로 금액 단위 변환
with source as (
    select * from {{ source('jaffle_shop', 'raw_payments') }}
),

renamed as (
    select
        id                                      as payment_id,
        order_id,
        payment_method,
        {{ cents_to_dollars('amount') }}        as amount
    from source
)

select * from renamed
