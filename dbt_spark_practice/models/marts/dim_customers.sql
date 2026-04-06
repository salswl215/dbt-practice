-- Design Ref: §4.3 — marts 레이어: 고객 차원 테이블 — 고객별 주문 이력 집계 (materialized=table)
{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('fct_orders') }}
),

customer_orders as (
    select
        customer_id,
        min(order_date)     as first_order_date,
        max(order_date)     as most_recent_order_date,
        count(order_id)     as number_of_orders,
        sum(amount)         as lifetime_value
    from orders
    group by 1
)

select
    customers.customer_id,
    customers.first_name,
    customers.last_name,
    customer_orders.first_order_date,
    customer_orders.most_recent_order_date,
    coalesce(customer_orders.number_of_orders, 0)   as number_of_orders,
    coalesce(customer_orders.lifetime_value, 0)     as lifetime_value
from customers
left join customer_orders using (customer_id)
