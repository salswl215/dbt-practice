-- Design Ref: §5 — Jinja 매크로 학습: 인자 있는 매크로, 기본값 설정, SQL 인라인 삽입
-- 사용처: stg_payments.sql — amount 컬럼 단위 변환 (cents → dollars)
{% macro cents_to_dollars(column_name, scale=2) %}
    ({{ column_name }} / 100)::decimal(16, {{ scale }})
{% endmacro %}
