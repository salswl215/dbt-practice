# dbt-practice

dbt(data build tool) 학습용 프로젝트입니다. Apache Spark를 백엔드로 사용하며, 레이어별 모델 구조와 materialization 차이를 실습합니다.

## 기술 스택

- **dbt** — 데이터 변환 및 모델링
- **Apache Spark** (Thrift Server) — SQL 실행 엔진
- **Docker** — Spark 환경 실행

## 프로젝트 구조

```
models/
├── staging/       # 원본 데이터 정제 (view)
├── intermediate/  # 중간 변환 로직 (view)
└── marts/         # 최종 분석용 테이블 (table)

seeds/
├── raw_customers.csv
├── raw_orders.csv
└── raw_payments.csv
```

## 모델 목록

| 레이어 | 모델 | 설명 |
|--------|------|------|
| staging | `stg_customers` | 고객 원본 데이터 정제 |
| staging | `stg_orders` | 주문 원본 데이터 정제 |
| staging | `stg_payments` | 결제 원본 데이터 정제 |
| intermediate | `int_orders_enriched` | 주문 + 결제 조합 |
| marts | `dim_customers` | 고객 차원 테이블 |
| marts | `fct_orders` | 주문 팩트 테이블 |

## 실행 방법

### 1. Spark 실행

```bash
docker-compose up -d
```

Spark UI: http://localhost:4040

### 2. dbt 실행

```bash
# seed 데이터 로드
dbt seed

# 모델 빌드
dbt run

# 테스트
dbt test
```
