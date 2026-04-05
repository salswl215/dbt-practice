# dbt-glue-practice Planning Document

> **Summary**: dbt-glue + 로컬 Spark을 활용한 dbt 핵심 개념 실습 (Jaffle Shop 도메인)
>
> **Project**: dbt-practice
> **Version**: 0.1.0
> **Author**: salswl215
> **Date**: 2026-04-05
> **Status**: Draft

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | dbt의 핵심 기능(모델 레이어, 소스/테스트, 매크로)을 실제 코드로 작성해본 경험 없이 이론만 아는 상태 |
| **Solution** | Jaffle Shop 샘플 데이터(CSV)를 dbt-spark 로컬 모드로 처리하며, staging→intermediate→marts 레이어 패턴을 직접 구성 |
| **Function/UX Effect** | dbt 프로젝트 구조를 한 눈에 파악할 수 있는 완성된 실습 레포와, `dbt run/test/docs` 명령으로 전체 파이프라인이 실행되는 경험 |
| **Core Value** | 실제 데이터 팀에서 쓰는 dbt 패턴(레이어 분리, 계약 테스트, Jinja 매크로)을 손으로 익혀 실무 적응력 확보 |

---

## Context Anchor

> Auto-generated from Executive Summary. Propagated to Design/Do documents for context continuity.

| Key | Value |
|-----|-------|
| **WHY** | dbt 핵심 기능을 이론이 아닌 실습으로 익히기 위함 |
| **WHO** | dbt 학습 중인 데이터 엔지니어/분석가 (본인) |
| **RISK** | dbt-glue는 AWS Glue 세션이 필요하나, 로컬 모드(dbt-spark)로 대체 시 일부 Glue 전용 기능 미검증 가능성 |
| **SUCCESS** | `dbt run`, `dbt test`, `dbt docs generate` 모두 오류 없이 통과 / 3개 레이어 모델 구성 완료 |
| **SCOPE** | Phase 1: 프로젝트 뼈대 + profiles.yml / Phase 2: 모델 레이어 구성 / Phase 3: 소스·테스트 / Phase 4: 매크로 |

---

## 1. Overview

### 1.1 Purpose

dbt의 핵심 워크플로우를 로컬 환경에서 직접 작성하고 실행함으로써, 실무 수준의 dbt 프로젝트 구조 이해를 목표로 한다.

### 1.2 Background

`dbt-glue`는 AWS Glue 세션 위에서 동작하지만, 로컬 실습을 위해 **dbt-spark + PySpark 로컬 모드**를 함께 설치해 AWS 비용 없이 동일한 SQL 변환 로직을 테스트할 수 있다. 실습 데이터는 dbt 공식 예제인 **Jaffle Shop** (주문/고객/결제 CSV)을 사용한다.

### 1.3 Related Documents

- dbt-glue 공식 문서: https://docs.getdbt.com/docs/core/connect-data-platform/glue-setup
- dbt-spark 로컬 모드: https://docs.getdbt.com/docs/core/connect-data-platform/spark-setup
- Jaffle Shop 데이터: https://github.com/dbt-labs/jaffle_shop

---

## 2. Scope

### 2.1 In Scope

- [x] dbt 프로젝트 초기화 (`dbt init`) 및 `profiles.yml` 로컬 Spark 설정
- [x] Jaffle Shop CSV 시드 파일 로드 (`dbt seed`)
- [x] 모델 레이어 3단계 구성: `staging` → `intermediate` → `marts`
- [x] `sources.yml` 정의 및 소스 freshness 설정
- [x] `schema.yml` 기반 generic 테스트 (not_null, unique, accepted_values, relationships)
- [x] Jinja 템플릿 활용 (ref, source, config 매크로)
- [x] 커스텀 매크로 1개 이상 작성 (`macros/` 디렉토리)
- [x] `dbt docs generate && dbt docs serve` 로 카탈로그 확인

### 2.2 Out of Scope

- AWS Glue 실제 세션 연결 (로컬 Spark으로 대체)
- CI/CD 파이프라인 구성
- 증분(Incremental) 모델 구현
- dbt Cloud 사용

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-01 | `dbt seed`로 Jaffle Shop CSV 3개(customers, orders, payments)를 로컬 Spark에 로드 | High | Pending |
| FR-02 | staging 레이어: 각 시드 테이블을 1:1 매핑하는 모델 3개 작성 | High | Pending |
| FR-03 | intermediate 레이어: 조인/집계 로직을 포함한 모델 1-2개 작성 | High | Pending |
| FR-04 | marts 레이어: 최종 분석용 모델 1개 작성 (예: `fct_orders`) | High | Pending |
| FR-05 | `sources.yml`에 원천 소스 정의, `schema.yml`에 컬럼 테스트 작성 | High | Pending |
| FR-06 | `dbt test` 실행 시 모든 테스트 통과 | High | Pending |
| FR-07 | 커스텀 매크로 1개 이상 작성 및 모델에서 호출 | Medium | Pending |
| FR-08 | `dbt docs generate`로 카탈로그 생성 확인 | Medium | Pending |

### 3.2 Non-Functional Requirements

| Category | Criteria | Measurement Method |
|----------|----------|-------------------|
| 실행 가능성 | 로컬 환경(poetry shell)에서 `dbt run` 오류 없이 완료 | 직접 실행 |
| 가독성 | 모델 파일에 `description` 메타데이터 포함 | schema.yml 확인 |
| 재현성 | `dbt clean && dbt seed && dbt run && dbt test` 순서로 완전 재현 | 순서대로 실행 |

---

## 4. Success Criteria

### 4.1 Definition of Done

- [ ] `dbt debug` 연결 성공 (로컬 Spark)
- [ ] `dbt seed` — 3개 테이블 로드 완료
- [ ] `dbt run` — staging(3) + intermediate(2) + marts(1) 모델 전부 성공
- [ ] `dbt test` — 모든 generic 테스트 통과
- [ ] `dbt docs generate` — catalog.json 생성 확인

### 4.2 Quality Criteria

- [ ] 모든 모델에 `config()` 블록으로 materialization 명시 (view/table)
- [ ] staging 모델은 원천 컬럼명 그대로 유지 (rename만 허용)
- [ ] `ref()`/`source()` 함수를 통한 의존성 명시 (하드코딩 테이블명 금지)

---

## 5. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| dbt-glue와 dbt-spark 동시 설치 시 의존성 충돌 | High | Medium | poetry extras로 분리, `dbt-spark[PyHive]` 설치 후 profiles.yml에 `method: local` 설정 |
| PySpark 로컬 모드 JVM 미설치 | Medium | Medium | Java 17+ 설치 확인, `JAVA_HOME` 환경변수 설정 |
| Jaffle Shop 데이터 인코딩 문제 | Low | Low | UTF-8 명시 (`dbt_project.yml`에 `seeds.encoding` 설정) |

---

## 6. Impact Analysis

### 6.1 Changed Resources

| Resource | Type | Change Description |
|----------|------|--------------------|
| `dbt_project.yml` | Config | dbt 프로젝트 설정 (name, version, model paths) |
| `profiles.yml` | Config | 로컬 Spark 연결 정보 추가 |
| `models/` | Directory | staging/intermediate/marts 하위 구조 신규 생성 |
| `seeds/` | Directory | Jaffle Shop CSV 3개 추가 |
| `macros/` | Directory | 커스텀 매크로 신규 생성 |

### 6.2 Current Consumers

신규 프로젝트이므로 기존 consumer 없음.

### 6.3 Verification

- [ ] `pyproject.toml`의 dbt-glue 의존성과 로컬 Spark 설치 충돌 없음 확인

---

## 7. Architecture Considerations

### 7.1 Project Level Selection

| Level | Characteristics | Selected |
|-------|-----------------|:--------:|
| **Starter** | 단일 레이어, 단순 구조 | ☐ |
| **Dynamic** | 3-레이어 모델 분리, 소스/테스트/매크로 포함 | ☑ |
| **Enterprise** | Incremental, 파티셔닝, 멀티 프로젝트 | ☐ |

### 7.2 Key Architectural Decisions

| Decision | Options | Selected | Rationale |
|----------|---------|----------|-----------|
| dbt 실행 엔진 | dbt-glue / dbt-spark local / dbt-duckdb | dbt-spark (method: local) | AWS 비용 없이 로컬 실습 가능 |
| Materialization 기본값 | view / table / incremental | staging=view, marts=table | 실습 목적으로 명시적 차이 체험 |
| 시드 데이터 | Jaffle Shop CSV / 직접 생성 | Jaffle Shop CSV | dbt 공식 예제로 레퍼런스 풍부 |
| 매크로 전략 | 없음 / 인라인 / macros/ 디렉토리 | macros/ 디렉토리 | 재사용성 패턴 학습 |

### 7.3 폴더 구조

```
dbt-practice/
├── dbt_project.yml          # dbt 프로젝트 메타 설정
├── profiles.yml             # 연결 정보 (로컬 Spark)
├── packages.yml             # 외부 패키지 (dbt-utils 등)
├── seeds/                   # Jaffle Shop CSV 원천 데이터
│   ├── raw_customers.csv
│   ├── raw_orders.csv
│   └── raw_payments.csv
├── models/
│   ├── staging/             # 원천 → 정제 (1:1 매핑, view)
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   ├── stg_payments.sql
│   │   └── schema.yml       # 소스 정의 + 컬럼 테스트
│   ├── intermediate/        # 조인/집계 중간 처리 (view)
│   │   ├── int_orders_enriched.sql
│   │   └── schema.yml
│   └── marts/               # 최종 분석 테이블 (table)
│       ├── fct_orders.sql
│       ├── dim_customers.sql
│       └── schema.yml
├── macros/
│   └── cents_to_dollars.sql # 금액 단위 변환 매크로 예시
├── tests/                   # singular 테스트 (선택)
└── docs/                    # PDCA 문서
```

---

## 8. Convention Prerequisites

### 8.1 Existing Project Conventions

- [ ] `CLAUDE.md` 없음 (신규 프로젝트)
- [ ] dbt 공식 스타일 가이드 참고 예정

### 8.2 Conventions to Define/Verify

| Category | Rule |
|----------|------|
| **모델 명명** | `stg_<source>__<object>`, `int_<verb>`, `fct_/dim_` 접두사 |
| **컬럼 명명** | snake_case, boolean은 `is_/has_` 접두사 |
| **CTE 스타일** | 모델 상단에 `with` 블록으로 명시적 CTE 구성 |
| **ref/source** | 하드코딩 테이블명 절대 금지, 반드시 `ref()`/`source()` 사용 |

### 8.3 Environment Variables Needed

| Variable | Purpose | Scope |
|----------|---------|-------|
| `JAVA_HOME` | PySpark JVM 경로 | Shell |
| `DBT_PROFILES_DIR` | profiles.yml 위치 지정 (선택) | Shell |

---

## 9. Next Steps

1. [ ] Design 문서 작성: 각 모델 SQL 스펙 및 profiles.yml 설정 상세화
2. [ ] `dbt-spark[PyHive]` 설치 및 `profiles.yml` 작성
3. [ ] Jaffle Shop CSV 다운로드 후 `seeds/` 배치
4. [ ] 모델 레이어별 순서대로 구현

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-04-05 | Initial draft | salswl215 |
