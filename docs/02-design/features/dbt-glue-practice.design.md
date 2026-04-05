# dbt-glue-practice Design Document

> **Summary**: dbt-spark 로컬 모드 + Jaffle Shop CSV로 3-레이어 dbt 실습 프로젝트 상세 설계
>
> **Project**: dbt-practice
> **Version**: 0.1.0
> **Author**: salswl215
> **Date**: 2026-04-05
> **Status**: Draft
> **Planning Doc**: [dbt-glue-practice.plan.md](../01-plan/features/dbt-glue-practice.plan.md)

---

## Context Anchor

> Copied from Plan document. Ensures strategic context survives Design→Do handoff.

| Key | Value |
|-----|-------|
| **WHY** | dbt 핵심 기능을 이론이 아닌 실습으로 익히기 위함 |
| **WHO** | dbt 학습 중인 데이터 엔지니어/분석가 (본인) |
| **RISK** | dbt-glue는 AWS Glue 세션이 필요하나, 로컬 모드(dbt-spark)로 대체 시 일부 Glue 전용 기능 미검증 가능성 |
| **SUCCESS** | `dbt run`, `dbt test`, `dbt docs generate` 모두 오류 없이 통과 / 3개 레이어 모델 구성 완료 |
| **SCOPE** | Phase 1: 프로젝트 뼈대 + profiles.yml / Phase 2: 모델 레이어 구성 / Phase 3: 소스·테스트 / Phase 4: 매크로 |

---

## 1. Overview

### 1.1 Design Goals

- `dbt-spark` 로컬 모드로 AWS 없이 완전 실행 가능한 환경 구성
- Jaffle Shop 도메인으로 staging → intermediate → marts 레이어 패턴 구현
- `dbt run / test / docs` 전체 명령이 오류 없이 통과하는 완성된 프로젝트 구조

### 1.2 Design Principles

- **레이어 책임 분리**: staging은 정제만, intermediate는 변환, marts는 집계/최종 출력
- **의존성 명시**: 모든 모델 간 참조는 `ref()` / `source()` 함수만 사용
- **설명 포함**: 모든 모델과 컬럼에 `description` 메타데이터 작성

---

## 2. Architecture

### 2.0 Architecture Comparison

| 기준 | Option A: Minimal | Option B: Clean | **Option C: Pragmatic ✅** |
|------|:-:|:-:|:-:|
| 레이어 수 | 1 (staging만) | 3 (엄격 분리) | **3 (실용적 구성)** |
| sources.yml 위치 | staging | 레이어별 분리 | **staging만** |
| 매크로 | 없음 | dbt-utils + 커스텀 2개 | **커스텀 1개** |
| 파일 수 | ~8 | ~18 | **~13** |
| 학습 적합성 | 낮음 | 과도함 | **최적** |

**Selected**: Option C — Pragmatic
**Rationale**: dbt 공식 Best Practice 패턴을 그대로 따르면서 불필요한 복잡도 없이 핵심 개념을 모두 실습할 수 있음.

### 2.1 데이터 플로우

```
seeds/ (CSV)
  ├── raw_customers.csv
  ├── raw_orders.csv
  └── raw_payments.csv
         │
         ▼ dbt seed
  [Spark 로컬 테이블]
         │
         ▼ source()
  staging/ (view)
  ├── stg_customers   — id 정제, 컬럼 rename
  ├── stg_orders      — status 정제, 날짜 타입 변환
  └── stg_payments    — amount cents→dollars 변환 (매크로 사용)
         │
         ▼ ref()
  intermediate/ (view)
  └── int_orders_enriched  — stg_orders + stg_payments 조인
         │
         ▼ ref()
  marts/ (table)
  ├── fct_orders      — 주문 팩트 테이블
  └── dim_customers   — 고객 차원 테이블 (lifetime_value 포함)
```

### 2.2 의존성 그래프

```
raw_customers ──▶ stg_customers ──────────────────────────▶ dim_customers
raw_orders    ──▶ stg_orders    ──▶ int_orders_enriched ──▶ fct_orders
raw_payments  ──▶ stg_payments  ──▶ int_orders_enriched
```

---

## 3. 환경 설정 스펙

### 3.1 profiles.yml (로컬 Spark 설정)

```yaml
# ~/.dbt/profiles.yml 또는 프로젝트 루트 (DBT_PROFILES_DIR 설정 시)
dbt_practice:
  target: dev
  outputs:
    dev:
      type: spark
      method: local          # AWS 없이 로컬 PySpark 사용
      schema: jaffle_shop    # Spark 데이터베이스(=스키마) 이름
      threads: 4
      connect_retries: 0
      connect_timeout: 10
      host: localhost
      port: 10001
      user: dbt
```

> **주의**: `method: local`은 `dbt-spark[PyHive]` extras가 필요하지 않음.  
> PySpark를 직접 실행하므로 `JAVA_HOME` 환경변수와 Java 17+ 설치 필수.

### 3.2 dbt_project.yml 핵심 설정

```yaml
name: 'dbt_practice'
version: '1.0.0'
config-version: 2

profile: 'dbt_practice'

model-paths: ["models"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
test-paths: ["tests"]

models:
  dbt_practice:
    staging:
      +materialized: view
    intermediate:
      +materialized: view
    marts:
      +materialized: table

seeds:
  dbt_practice:
    +column_types:
      id: bigint
```

### 3.3 패키지 의존성 추가

```bash
# poetry로 dbt-spark 추가 (dbt-glue는 이미 설치됨)
poetry add "dbt-spark>=1.9.0"
```

```yaml
# packages.yml (dbt 패키지 — 선택사항, 학습 목적)
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0"]
```

---

## 4. 모델 상세 스펙

### 4.1 staging 레이어

#### `stg_customers.sql`

```sql
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
```

#### `stg_orders.sql`

```sql
with source as (
    select * from {{ source('jaffle_shop', 'raw_orders') }}
),

renamed as (
    select
        id              as order_id,
        user_id         as customer_id,
        order_date,
        status
    from source
)

select * from renamed
```

#### `stg_payments.sql`

```sql
with source as (
    select * from {{ source('jaffle_shop', 'raw_payments') }}
),

renamed as (
    select
        id                                          as payment_id,
        orderid                                     as order_id,
        payment_method,
        {{ cents_to_dollars('amount') }}            as amount   -- 커스텀 매크로 사용
    from source
)

select * from renamed
```

#### `staging/schema.yml` (sources + 컬럼 테스트 통합)

```yaml
version: 2

sources:
  - name: jaffle_shop
    description: "Jaffle Shop 원천 데이터 (dbt seed로 로드)"
    tables:
      - name: raw_customers
        description: "원천 고객 테이블"
      - name: raw_orders
        description: "원천 주문 테이블"
      - name: raw_payments
        description: "원천 결제 테이블"

models:
  - name: stg_customers
    description: "정제된 고객 모델"
    columns:
      - name: customer_id
        description: "고객 PK"
        tests:
          - unique
          - not_null

  - name: stg_orders
    description: "정제된 주문 모델"
    columns:
      - name: order_id
        tests: [unique, not_null]
      - name: status
        tests:
          - accepted_values:
              values: ['placed', 'shipped', 'completed', 'return_pending', 'returned']

  - name: stg_payments
    description: "정제된 결제 모델 (금액 단위: dollars)"
    columns:
      - name: payment_id
        tests: [unique, not_null]
      - name: payment_method
        tests:
          - accepted_values:
              values: ['credit_card', 'coupon', 'bank_transfer', 'gift_card']
```

---

### 4.2 intermediate 레이어

#### `int_orders_enriched.sql`

```sql
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
```

#### `intermediate/schema.yml`

```yaml
version: 2

models:
  - name: int_orders_enriched
    description: "결제 금액이 합산된 주문 모델"
    columns:
      - name: order_id
        tests: [unique, not_null]
      - name: amount
        description: "주문 총 결제 금액 (dollars)"
```

---

### 4.3 marts 레이어

#### `fct_orders.sql`

```sql
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
```

#### `dim_customers.sql`

```sql
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
        min(order_date)                 as first_order_date,
        max(order_date)                 as most_recent_order_date,
        count(order_id)                 as number_of_orders,
        sum(amount)                     as lifetime_value
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
```

#### `marts/schema.yml`

```yaml
version: 2

models:
  - name: fct_orders
    description: "주문 팩트 테이블 — 분석의 핵심 테이블"
    columns:
      - name: order_id
        tests: [unique, not_null]
      - name: customer_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id

  - name: dim_customers
    description: "고객 차원 테이블 — 고객별 주문 이력 포함"
    columns:
      - name: customer_id
        tests: [unique, not_null]
```

---

## 5. 매크로 스펙

### `macros/cents_to_dollars.sql`

```sql
{% macro cents_to_dollars(column_name, scale=2) %}
    ({{ column_name }} / 100)::numeric(16, {{ scale }})
{% endmacro %}
```

**사용 목적**: `stg_payments`에서 `amount` 컬럼 단위 변환 (cents → dollars)
**Jinja 학습 포인트**: 인자 있는 매크로, 기본값 설정, SQL 인라인 삽입

---

## 6. 시드 데이터 스펙

Jaffle Shop 공식 CSV를 `seeds/` 에 배치:

| 파일명 | 주요 컬럼 | 행 수 |
|--------|-----------|-------|
| `raw_customers.csv` | id, first_name, last_name | ~100 |
| `raw_orders.csv` | id, user_id, order_date, status | ~99 |
| `raw_payments.csv` | id, orderid, payment_method, amount | ~113 |

**다운로드 방법:**
```bash
# seeds/ 폴더에 직접 다운로드
curl -o seeds/raw_customers.csv https://raw.githubusercontent.com/dbt-labs/jaffle_shop/main/seeds/raw_customers.csv
curl -o seeds/raw_orders.csv    https://raw.githubusercontent.com/dbt-labs/jaffle_shop/main/seeds/raw_orders.csv
curl -o seeds/raw_payments.csv  https://raw.githubusercontent.com/dbt-labs/jaffle_shop/main/seeds/raw_payments.csv
```

---

## 7. 테스트 계획

### 7.1 테스트 범위

| 테스트 유형 | 위치 | 내용 |
|------------|------|------|
| Generic (not_null) | schema.yml | 모든 PK 컬럼 |
| Generic (unique) | schema.yml | 모든 PK 컬럼 |
| Generic (accepted_values) | schema.yml | status, payment_method |
| Generic (relationships) | marts/schema.yml | fct_orders.customer_id → dim_customers |

### 7.2 전체 실행 순서

```bash
# 환경 진입
poetry shell

# 1. 연결 확인
dbt debug

# 2. 시드 로드
dbt seed

# 3. 모델 실행
dbt run

# 4. 테스트 실행
dbt test

# 5. 문서 생성 및 확인
dbt docs generate
dbt docs serve  # http://localhost:8080
```

---

## 8. 에러 처리 가이드

| 상황 | 원인 | 해결 방법 |
|------|------|-----------|
| `dbt debug` 실패 | Java 미설치 / JAVA_HOME 미설정 | `java -version` 확인, `export JAVA_HOME=$(/usr/libexec/java_home)` |
| `dbt seed` 실패 | CSV 인코딩 문제 | `dbt_project.yml`에 `seeds: +column_types:` 추가 |
| `dbt run` 실패 | `source()` 참조 오류 | `sources.yml`의 `name`이 `source()` 첫 번째 인자와 일치하는지 확인 |
| `dbt test` 실패 | accepted_values 불일치 | 실제 CSV 데이터의 고유값과 schema.yml 값 목록 비교 |
| 매크로 `not found` | macros/ 경로 미설정 | `dbt_project.yml`에 `macro-paths: ["macros"]` 확인 |

---

## 9. 컨벤션

| 카테고리 | 규칙 |
|----------|------|
| **모델 명명** | `stg_<table>`, `int_<verb>_<noun>`, `fct_<event>`, `dim_<entity>` |
| **컬럼 명명** | snake_case, PK는 `<entity>_id` |
| **CTE 스타일** | `with source as (...), renamed as (...) select * from renamed` |
| **ref/source** | 하드코딩 테이블명 절대 금지 |
| **materialization** | `config()` 블록으로 명시 (staging=view, marts=table) |

---

## 10. 환경 변수

| 변수 | 용도 | 설정 방법 |
|------|------|----------|
| `JAVA_HOME` | PySpark JVM | `export JAVA_HOME=$(/usr/libexec/java_home)` |
| `DBT_PROFILES_DIR` | profiles.yml 위치 지정 (선택) | `export DBT_PROFILES_DIR=$(pwd)` |

---

## 11. Implementation Guide

### 11.1 최종 파일 구조

```
dbt-practice/
├── dbt_project.yml
├── profiles.yml
├── packages.yml               (선택 — dbt-utils)
├── seeds/
│   ├── raw_customers.csv
│   ├── raw_orders.csv
│   └── raw_payments.csv
├── models/
│   ├── staging/
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   ├── stg_payments.sql
│   │   └── schema.yml
│   ├── intermediate/
│   │   ├── int_orders_enriched.sql
│   │   └── schema.yml
│   └── marts/
│       ├── fct_orders.sql
│       ├── dim_customers.sql
│       └── schema.yml
└── macros/
    └── cents_to_dollars.sql
```

생성 파일: **13개** | 수정 파일: **2개** (pyproject.toml, 신규 dbt_project.yml)

### 11.2 구현 순서

1. [ ] **Module 1**: 환경 설정 — `dbt_project.yml`, `profiles.yml`, Java/PySpark 확인
2. [ ] **Module 2**: 시드 로드 — CSV 다운로드, `dbt seed` 실행
3. [ ] **Module 3**: staging 레이어 — 3개 모델 + `schema.yml` (sources + 테스트)
4. [ ] **Module 4**: intermediate 레이어 — `int_orders_enriched.sql` + `schema.yml`
5. [ ] **Module 5**: marts 레이어 — `fct_orders.sql`, `dim_customers.sql` + `schema.yml`
6. [ ] **Module 6**: 매크로 — `cents_to_dollars.sql` 작성 및 `stg_payments`에 적용
7. [ ] **Module 7**: 전체 검증 — `dbt run && dbt test && dbt docs generate`

### 11.3 Session Guide

#### Module Map

| Module | Scope Key | Description | 예상 작업량 |
|--------|-----------|-------------|:-----------:|
| 환경 설정 | `module-1` | dbt_project.yml, profiles.yml, Java 확인 | 낮음 |
| 시드 + staging | `module-2` | CSV 다운로드, stg_* 3개 모델, schema.yml | 중간 |
| intermediate + marts | `module-3` | int_*, fct_*, dim_* 모델 + schema.yml | 중간 |
| 매크로 + 검증 | `module-4` | cents_to_dollars 매크로, 전체 dbt run/test/docs | 낮음 |

#### Recommended Session Plan

| Session | 범위 | 명령 |
|---------|------|------|
| Session 1 | Plan + Design | `/pdca plan`, `/pdca design` |
| Session 2 | Module 1+2 | `/pdca do dbt-glue-practice --scope module-1,module-2` |
| Session 3 | Module 3+4 | `/pdca do dbt-glue-practice --scope module-3,module-4` |
| Session 4 | Check + Report | `/pdca analyze dbt-glue-practice` |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-04-05 | Initial draft (Option C — Pragmatic) | salswl215 |
