-- Design Ref: §4.3 — marts 레이어: 주문 팩트 테이블 (materialized=table)
-- Plan SC: 최종 분석용 모델 — int_orders_enriched를 기반으로 한 팩트 테이블
{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('int_orders_enriched') }}
)

select
    order_id,
    customer_id,
    order_date,
    status,
    amount
from orders
