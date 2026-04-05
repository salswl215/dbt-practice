# Iceberg 실습 학습 포인트 정리

> **Summary**: dbt + Spark 로컬 환경에서 Apache Iceberg를 실습할 때 단계별로 익힐 수 있는 핵심 개념, 실습 쿼리, 실무 연결점 학습 로드맵
>
> **Project**: dbt-practice
> **Author**: salswl215
> **Date**: 2026-04-05
> **Status**: Reference

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | Iceberg를 이론으로만 알고 있어 실무 데이터 파이프라인에서 왜/어떻게 쓰는지 체감하지 못하는 상태 |
| **Solution** | 로컬 Spark + dbt 환경에서 단계별 실습 쿼리를 직접 실행하며 개념을 체험으로 확인 |
| **Function/UX Effect** | 각 Iceberg 기능을 실행하고 결과를 눈으로 확인하는 학습 체크리스트 완성 |
| **Core Value** | AWS Glue/Athena/Databricks 실무 투입 시 Iceberg 관련 질문에 실습 경험으로 답할 수 있는 역량 |

---

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | Iceberg 실무 패턴을 손으로 익혀 데이터 엔지니어 역량 확보 |
| **WHO** | dbt 기초 실습 완료 후 Lakehouse 포맷을 배우려는 학습자 (본인) |
| **RISK** | 로컬 실습은 대규모 데이터 성능 특성 미확인 — 개념 검증 수준으로 활용 |
| **SUCCESS** | 5개 핵심 기능(Time Travel, Schema Evolution, Partition Evolution, Snapshot, Merge) 각 1회 이상 직접 실행 |
| **SCOPE** | Phase 1: 왜 Iceberg인가 / Phase 2: 핵심 기능 실습 / Phase 3: dbt 연동 / Phase 4: 실무 연결 |

---

## Phase 1. 왜 Iceberg인가 — 기존 방식의 한계

### 1.1 Hive/Parquet 방식의 문제

| 문제 | 설명 | Iceberg 해결 방식 |
|------|------|------------------|
| **소규모 파일 폭발** | 파티션에 파일이 계속 쌓여 수천 개가 됨 | Compaction으로 자동 병합 |
| **UPDATE/DELETE 불가** | Parquet는 불변(immutable) — 수정하려면 전체 파티션 재작성 | Copy-on-Write / Merge-on-Read |
| **스키마 변경 위험** | 컬럼 추가/삭제 시 기존 파일 깨짐 | 메타데이터 레벨 스키마 진화 |
| **파티션 변경 불가** | 파티션 컬럼 바꾸면 전체 재처리 | Partition Evolution (메타데이터만 변경) |
| **동시성 문제** | 여러 잡이 동시에 쓰면 데이터 손실 가능 | Optimistic Concurrency Control |

### 1.2 Iceberg가 해결하는 핵심 아키텍처

```
Iceberg 테이블 구성 요소:

catalog (메타스토어)
  └── table
        ├── metadata/
        │    ├── v1.metadata.json   ← 현재 snapshot 포인터
        │    ├── v2.metadata.json
        │    └── snap-xxxxx.avro   ← snapshot (manifest list)
        └── data/
             ├── part-0001.parquet
             └── part-0002.parquet

핵심: "어떤 파일이 현재 테이블인가"를 metadata.json이 결정
      → Time Travel = 과거 metadata.json을 읽으면 됨
```

---

## Phase 2. 핵심 기능별 실습 쿼리

### 2.1 테이블 생성 (dbt 대신 직접 SQL)

```sql
-- Spark SQL로 Iceberg 테이블 생성
CREATE TABLE spark_catalog.jaffle_shop.orders_iceberg (
    order_id    BIGINT,
    customer_id BIGINT,
    order_date  DATE,
    status      STRING,
    amount      DECIMAL(16,2)
)
USING iceberg
PARTITIONED BY (months(order_date));

-- 데이터 삽입 (dbt seed 결과에서)
INSERT INTO spark_catalog.jaffle_shop.orders_iceberg
SELECT * FROM spark_catalog.jaffle_shop.fct_orders;
```

---

### 2.2 Time Travel ⏪

**개념**: 모든 쓰기 작업은 새 snapshot을 생성. 과거 snapshot ID나 타임스탬프로 이전 상태 조회 가능.

```sql
-- 현재 snapshot 목록 확인
SELECT snapshot_id, committed_at, operation
FROM spark_catalog.jaffle_shop.orders_iceberg.snapshots;

-- snapshot ID로 과거 상태 조회
SELECT COUNT(*) FROM spark_catalog.jaffle_shop.orders_iceberg
VERSION AS OF 1234567890;

-- 타임스탬프로 과거 상태 조회
SELECT COUNT(*) FROM spark_catalog.jaffle_shop.orders_iceberg
TIMESTAMP AS OF '2026-01-01 00:00:00';
```

**실무 연결**: 데이터 파이프라인 장애 시 롤백, 감사(audit) 쿼리, A/B 데이터 비교

---

### 2.3 Schema Evolution 🔄

**개념**: 컬럼 추가/삭제/rename이 기존 데이터 파일을 건드리지 않고 메타데이터만 변경.

```sql
-- 컬럼 추가 (기존 데이터: NULL로 표시)
ALTER TABLE spark_catalog.jaffle_shop.orders_iceberg
ADD COLUMN is_returned BOOLEAN;

-- 컬럼 rename (기존 쿼리 하위 호환 유지 가능)
ALTER TABLE spark_catalog.jaffle_shop.orders_iceberg
RENAME COLUMN status TO order_status;

-- 컬럼 타입 변환 (호환 가능 범위 내)
ALTER TABLE spark_catalog.jaffle_shop.orders_iceberg
ALTER COLUMN amount TYPE DECIMAL(20,4);
```

**dbt 연결**: `dbt run` 후 컬럼이 추가된 모델 재실행 시 기존 데이터 보존 확인

**실무 연결**: 원천 스키마 변경에 안전하게 대응, 롤링 배포 시 하위 호환

---

### 2.4 Partition Evolution 📂

**개념**: 파티션 전략을 바꿔도 기존 데이터 재처리 없이 새 데이터부터 새 파티션 적용.

```sql
-- 기존: 월 단위 파티션
-- 변경: 일 단위로 전환 (신규 데이터부터 적용)
ALTER TABLE spark_catalog.jaffle_shop.orders_iceberg
ADD PARTITION FIELD days(order_date);

-- 기존 월 파티션 제거 (히스토리 유지)
ALTER TABLE spark_catalog.jaffle_shop.orders_iceberg
DROP PARTITION FIELD months(order_date);
```

**실무 연결**: 데이터 증가로 파티션 전략 변경 시 전체 재처리 비용 제거

---

### 2.5 MERGE INTO (Upsert) 🔀

**개념**: CDC(Change Data Capture) 패턴의 핵심 — 신규면 INSERT, 기존이면 UPDATE.

```sql
MERGE INTO spark_catalog.jaffle_shop.orders_iceberg AS target
USING (
    SELECT 1 AS order_id, 1 AS customer_id,
           DATE('2026-01-01') AS order_date,
           'completed' AS order_status,
           10.00 AS amount
) AS source
ON target.order_id = source.order_id
WHEN MATCHED THEN
    UPDATE SET order_status = source.order_status, amount = source.amount
WHEN NOT MATCHED THEN
    INSERT *;
```

**실무 연결**: Kafka/Kinesis 스트림 → Iceberg Upsert 패턴, SCD Type 1/2 구현

---

### 2.6 Snapshot 관리 & Compaction 🧹

```sql
-- 현재 테이블의 파일 현황 확인
SELECT file_path, file_size_in_bytes, record_count
FROM spark_catalog.jaffle_shop.orders_iceberg.files;

-- 오래된 snapshot 정리 (7일 이전)
CALL spark_catalog.system.expire_snapshots(
    table => 'jaffle_shop.orders_iceberg',
    older_than => TIMESTAMP '2026-01-01 00:00:00'
);

-- 소규모 파일 병합 (compaction)
CALL spark_catalog.system.rewrite_data_files(
    table => 'jaffle_shop.orders_iceberg',
    options => map('target-file-size-bytes', '134217728')
);
```

**실무 연결**: 운영 비용 절감, S3 파일 수 제한 회피, 쿼리 성능 최적화

---

## Phase 3. dbt + Iceberg 연동 패턴

### 3.1 dbt_project.yml 설정

```yaml
models:
  dbt_practice:
    staging:
      +materialized: view           # staging은 view 그대로
    intermediate:
      +materialized: view
    marts:
      +materialized: table
      +file_format: iceberg         # ← Iceberg 포맷 지정
      +location_root: /tmp/spark-warehouse
```

### 3.2 모델별 Iceberg 설정 (개별 오버라이드)

```sql
-- marts/fct_orders.sql
{{ config(
    materialized='incremental',
    file_format='iceberg',
    incremental_strategy='merge',   -- MERGE INTO 사용
    unique_key='order_id'
) }}

select * from {{ ref('int_orders_enriched') }}

{% if is_incremental() %}
    where order_date > (select max(order_date) from {{ this }})
{% endif %}
```

### 3.3 Iceberg + dbt Incremental 전략 비교

| 전략 | Iceberg 동작 | 사용 시점 |
|------|-------------|----------|
| `append` | 새 파일 추가 | 로그성 데이터, 중복 없음 보장 시 |
| `merge` | MERGE INTO | CDC, upsert 필요 시 (권장) |
| `insert_overwrite` | 파티션 덮어쓰기 | 전체 파티션 교체 시 |

---

## Phase 4. 실무 연결 포인트

### 4.1 AWS 환경에서의 Iceberg

| 로컬 실습 | AWS 실무 대응 |
|-----------|--------------|
| Spark 로컬 Thrift Server | AWS Glue (SparkContext) |
| `/tmp/spark-warehouse` | S3 버킷 (`s3://bucket/warehouse/`) |
| `spark_catalog` | AWS Glue Data Catalog |
| `CALL system.expire_snapshots` | AWS Glue Job으로 주기적 실행 |
| `dbt-spark` | `dbt-glue` (이미 설치됨) |

### 4.2 dbt-glue → Iceberg 전환 시 변경점

현재 프로젝트의 `dbt-glue`는 AWS Glue 연결 시 아래만 추가하면 Iceberg 사용 가능:

```yaml
# profiles.yml (AWS Glue 환경)
dbt_glue_prod:
  type: glue
  role_arn: arn:aws:iam::123456789012:role/GlueRole
  region: ap-northeast-2
  workers: 2
  worker_type: G.1X
  schema: jaffle_shop
  extra_jars:               # Iceberg JAR
    - s3://bucket/jars/iceberg-spark-runtime.jar
  conf:
    spark.sql.extensions: org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions
    spark.sql.catalog.glue_catalog.warehouse: s3://bucket/warehouse/
```

### 4.3 면접/업무 대비 핵심 질문

| 질문 | 핵심 답변 포인트 |
|------|----------------|
| "Iceberg vs Delta Lake vs Hudi 차이?" | 카탈로그 독립성, 파티션 진화, 커뮤니티 |
| "Time Travel을 왜 쓰나요?" | 장애 복구, 감사 로그, 재현 가능한 파이프라인 |
| "Compaction은 언제 실행하나요?" | 스트리밍 후 소규모 파일 누적 시, 쿼리 성능 저하 시 |
| "dbt에서 Iceberg incremental을 어떻게 쓰나요?" | `file_format=iceberg`, `incremental_strategy=merge` |

---

## 실습 체크리스트

- [ ] Phase 1: Iceberg 테이블 생성 + 데이터 로드
- [ ] Phase 2a: `snapshots` 조회 후 Time Travel 쿼리 실행
- [ ] Phase 2b: 컬럼 추가 후 기존 데이터 확인 (Schema Evolution)
- [ ] Phase 2c: 파티션 전략 변경 (Partition Evolution)
- [ ] Phase 2d: MERGE INTO로 upsert 실행
- [ ] Phase 2e: `expire_snapshots` / `rewrite_data_files` 실행
- [ ] Phase 3: dbt 모델에 `file_format: iceberg` 적용 후 `dbt run`
- [ ] Phase 3: incremental 모델 + `merge` 전략 실행

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-04-05 | Initial draft | salswl215 |
