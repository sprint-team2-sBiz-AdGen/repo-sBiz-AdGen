# FeedlyAI 모니터링 시스템

Prometheus와 Grafana를 사용한 FeedlyAI 프로젝트 모니터링 스택입니다.

## 빠른 시작

### 1. 모니터링 스택 시작

```bash
cd /home/leeyoungho/feedlyai/monitoring
docker-compose up -d
```

### 2. 접속

- **Grafana**: http://localhost:3000
  - 기본 계정: `admin` / `admin` (첫 로그인 시 비밀번호 변경 요구)
- **Prometheus**: http://localhost:9090

### 3. 중지

```bash
docker-compose down
```

## 구성 요소

### Prometheus (포트 9090)
- 메트릭 수집 및 저장
- 시계열 데이터베이스
- 알림 규칙 평가

### Grafana (포트 3000)
- 메트릭 시각화
- 대시보드 제공
- 알림 관리

### Node Exporter (포트 9100)
- 호스트 시스템 메트릭 수집
- CPU, 메모리, 디스크, 네트워크

### PostgreSQL Exporter (포트 9187)
- PostgreSQL 데이터베이스 메트릭 수집
- 연결 수, 쿼리 성능, 캐시 히트율 등

## 모니터링 대상

### 애플리케이션 서비스
- `app-ye`: 이미지 생성/분석
- `app-yh`: YOLO/Planner/Overlay/Eval/Judge
- `app-js`: FE/BFF & 업로드/Job 제출
- `app-sh`: 이미지 향상/배경 제거

**주의**: 각 서비스는 `/metrics` 엔드포인트를 노출해야 합니다. 
각 서비스에 Prometheus 클라이언트를 추가해야 합니다.

### 데이터베이스
- `postgres`: 공용 PostgreSQL (포트 5432)
- `postgres-ye`, `postgres-yh`, `postgres-js`, `postgres-sh`: 팀원별 DB

**현재 설정**: postgres-exporter는 공용 postgres만 모니터링합니다.
추가 DB 인스턴스를 모니터링하려면 설정을 확장해야 합니다.

### 인프라
- 호스트 시스템 리소스 (Node Exporter)
- Nginx (선택사항, 설정 필요)

## 네트워크 설정

모니터링 스택은 기존 `feedlyai_default` Docker 네트워크를 사용합니다.
이를 통해 기존 서비스들과 통신할 수 있습니다.

**중요**: 기존 서비스들이 실행 중이어야 모니터링이 가능합니다.

## 설정 파일 구조

```
monitoring/
├── docker-compose.yml          # 모니터링 스택 오케스트레이션
├── prometheus/
│   ├── prometheus.yml          # Prometheus 메인 설정
│   ├── alerts.yml              # 알림 규칙
│   └── targets/                # 타겟 설정 (참고용)
│       ├── apps.yml
│       ├── databases.yml
│       └── infrastructure.yml
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/        # 데이터 소스 자동 설정
│   │   │   └── prometheus.yml
│   │   └── dashboards/         # 대시보드 프로비저닝
│   │       └── dashboard.yml
│   └── dashboards/             # 커스텀 대시보드 JSON
└── README.md                   # 이 파일
```

## 서비스에 Prometheus 클라이언트 추가하기

각 FastAPI 서비스에 메트릭 노출을 추가해야 합니다:

### 1. requirements.txt에 추가
```txt
prometheus-client==0.19.0
```

### 2. main.py에 추가
```python
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi import Response

# 메트릭 정의
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint']
)

# /metrics 엔드포인트 추가
@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
```

### 3. 미들웨어 추가 (선택사항)
```python
import time
from fastapi import Request

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    
    http_requests_total.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    http_request_duration_seconds.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
    
    return response
```

## 알림 규칙

주요 알림 규칙은 `prometheus/alerts.yml`에 정의되어 있습니다:

- **서비스 다운**: 서비스가 1분 이상 응답하지 않음
- **높은 에러율**: 5xx 에러율이 1% 초과 (5분)
- **높은 응답 시간**: P95 응답 시간이 2초 초과 (5분)
- **높은 CPU 사용량**: CPU 사용률이 80% 초과 (5분)
- **높은 메모리 사용량**: 메모리 사용률이 90% 초과 (5분)
- **디스크 공간 부족**: 디스크 사용 가능 공간이 15% 미만 (5분)

알림은 Prometheus UI (`http://localhost:9090/alerts`)에서 확인할 수 있습니다.

## 대시보드

Grafana에서 대시보드를 생성하거나 기존 대시보드를 import할 수 있습니다.

### 기본 대시보드 생성 가이드

1. Grafana에 로그인
2. Dashboards → New Dashboard
3. Add visualization으로 패널 추가
4. PromQL 쿼리 작성

### 유용한 PromQL 쿼리 예시

```promql
# 서비스별 요청 수
rate(http_requests_total[5m])

# 평균 응답 시간 (P95)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# 에러율
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])

# CPU 사용률
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 메모리 사용률
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

## 문제 해결

### Prometheus가 메트릭을 수집하지 않음

1. 타겟 상태 확인: http://localhost:9090/targets
2. 네트워크 연결 확인: 같은 Docker 네트워크인지 확인
3. 서비스가 실행 중인지 확인
4. `/metrics` 엔드포인트가 노출되어 있는지 확인

### Grafana에서 데이터가 보이지 않음

1. 데이터 소스 연결 확인: Configuration → Data Sources
2. Prometheus URL 확인: `http://prometheus:9090`
3. Prometheus가 정상 작동하는지 확인

### 로그 확인

```bash
# 전체 로그
docker-compose logs

# 특정 서비스 로그
docker-compose logs prometheus
docker-compose logs grafana

# 실시간 로그
docker-compose logs -f
```

## 데이터 보관

- **보관 기간**: 15일 (설정 가능)
- **설정 위치**: `docker-compose.yml`의 `--storage.tsdb.retention.time` 옵션
- **데이터 위치**: `prometheus_data` Docker 볼륨

## 리소스 사용량

예상 리소스 사용량:
- **Prometheus**: CPU 100-200m, 메모리 200-500MB
- **Grafana**: CPU 50-100m, 메모리 100-200MB
- **Exporters**: 각각 CPU 10-50m, 메모리 20-50MB

## 보안

1. **Grafana 비밀번호 변경**: 첫 로그인 시 필수
2. **내부 네트워크 접근**: 모니터링 포트는 내부 네트워크에서만 접근 가능하도록 설정 권장
3. **민감한 메트릭**: 불필요한 메트릭 노출 최소화

## 참고 문서

- [상세 아키텍처 설계](../docs/MONITORING_ARCHITECTURE.md)
- [시각적 도식화](../docs/MONITORING_DIAGRAM.md)
- [운영 가이드](../docs/MONITORING_OPERATION_GUIDE.md)
- [요약 문서](../docs/MONITORING_SUMMARY.md)

## 다음 단계

1. ✅ 모니터링 스택 설정 완료
2. ⏳ 각 서비스에 Prometheus 클라이언트 추가
3. ⏳ 기본 대시보드 생성
4. ⏳ 알림 채널 설정 (선택사항)

