-- Design Ref: §4.2 — intermediate 레이어: stg_orders + stg_payments 조인, 주문별 총 결제금액 집계
with orders as (
    select * from {{ ref('stg_orders') }}
),

payments as (
    select
        order_id,
        sum(amount) as total_amount
    from {{ ref('stg_payments') }}
    group by 1
)

select
    orders.order_id,
    orders.customer_id,
    orders.order_date,
    orders.status,
    coalesce(payments.total_amount, 0) as amount
from orders
left join payments using (order_id)
