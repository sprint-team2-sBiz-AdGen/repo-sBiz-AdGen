# PostgreSQL LISTEN/NOTIFY 트리거 설정 가이드

## 📋 개요

`02_job_state_notify_trigger.sql` 파일은 `jobs` 테이블의 상태 변화를 실시간으로 감지하기 위한 PostgreSQL 트리거를 생성합니다.

## ⚠️ 중요: 실행 시점

PostgreSQL의 `docker-entrypoint-initdb.d` 디렉토리는 **컨테이너가 처음 생성될 때만** 자동으로 실행됩니다.

### 자동 실행되는 경우
- ✅ **새로운 데이터베이스 컨테이너를 처음 생성할 때**
  - 팀 도커에서 처음 `docker-compose up` 실행 시
  - 데이터베이스 볼륨이 없을 때

### 수동 실행이 필요한 경우
- ❌ **이미 데이터베이스가 존재하는 경우**
  - 기존 데이터베이스 볼륨이 있는 경우
  - 각 팀원의 로컬 데이터베이스

## 🚀 실행 방법

### 방법 1: 팀 도커에서 실행 (권장)

#### 공용 PostgreSQL (포트 5432)
```bash
docker exec -i feedlyai-postgres psql -U feedlyai -d feedlyai < db/init/02_job_state_notify_trigger.sql
```

#### 팀원별 PostgreSQL
```bash
# ye (포트 5434)
docker exec -i feedlyai-postgres-ye psql -U feedlyai -d feedlyai < db/init/02_job_state_notify_trigger.sql

# js (포트 5436)
docker exec -i feedlyai-postgres-js psql -U feedlyai -d feedlyai < db/init/02_job_state_notify_trigger.sql
```

### 방법 2: 컨테이너 내부에서 직접 실행

```bash
# 컨테이너 접속
docker exec -it feedlyai-postgres psql -U feedlyai -d feedlyai

# SQL 실행
\i /docker-entrypoint-initdb.d/02_job_state_notify_trigger.sql
```

또는

```bash
# 한 줄로 실행
docker exec -i feedlyai-postgres psql -U feedlyai -d feedlyai -f /docker-entrypoint-initdb.d/02_job_state_notify_trigger.sql
```

### 방법 3: 새 데이터베이스 컨테이너 생성 (자동 실행)

기존 데이터베이스 볼륨을 삭제하고 새로 생성하면 자동으로 실행됩니다:

```bash
# 주의: 기존 데이터가 모두 삭제됩니다!
docker-compose down -v  # 볼륨까지 삭제
docker-compose up -d postgres  # 새로 생성
```

## ✅ 트리거 확인

트리거가 정상적으로 생성되었는지 확인:

```bash
docker exec -i feedlyai-postgres psql -U feedlyai -d feedlyai -c "
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'job_state_change_trigger';
"
```

또는 함수 확인:

```bash
docker exec -i feedlyai-postgres psql -U feedlyai -d feedlyai -c "
SELECT 
    routine_name, 
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'notify_job_state_change';
"
```

## 🧪 테스트

트리거가 정상 작동하는지 테스트:

```bash
docker exec -i feedlyai-postgres psql -U feedlyai -d feedlyai <<EOF
-- 테스트: jobs 테이블 업데이트
UPDATE jobs 
SET status = 'done', current_step = 'test_step'
WHERE job_id = (SELECT job_id FROM jobs LIMIT 1);

-- 트리거 함수 직접 테스트 (선택사항)
SELECT notify_job_state_change();
EOF
```

## 📝 참고사항

1. **트리거는 데이터베이스별로 독립적입니다**
   - 공용 PostgreSQL과 각 팀원별 PostgreSQL은 별도로 실행해야 합니다.

2. **`CREATE OR REPLACE FUNCTION` 사용**
   - 이미 함수가 존재해도 안전하게 업데이트됩니다.

3. **`DROP TRIGGER IF EXISTS` 사용**
   - 이미 트리거가 존재해도 안전하게 재생성됩니다.

4. **자동 실행 vs 수동 실행**
   - 새로운 환경: 자동 실행 (docker-entrypoint-initdb.d)
   - 기존 환경: 수동 실행 필요

## 🔄 업데이트 시

트리거를 업데이트할 때는:

1. SQL 파일 수정
2. 각 데이터베이스에 수동으로 재실행 (방법 1 또는 2 사용)

## 📚 관련 문서

- [IMPLEMENTATION_PLAN_LISTEN_NOTIFY.md](../../IMPLEMENTATION_PLAN_LISTEN_NOTIFY.md) - 전체 구현 계획
- [01_schema.sql](./01_schema.sql) - 데이터베이스 스키마

