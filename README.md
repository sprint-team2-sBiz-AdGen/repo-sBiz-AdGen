# FeedlyAI - AI 기반 광고 이미지 생성 파이프라인

FeedlyAI는 AI 기술을 활용하여 인스타그램 피드용 광고 이미지를 자동으로 생성하는 멀티 서비스 아키텍처 프로젝트입니다.

## 📋 목차

- [프로젝트 개요](#프로젝트-개요)
- [아키텍처](#아키텍처)
- [빠른 시작](#빠른-시작)
- [서비스 구성](#서비스-구성)
- [데이터베이스](#데이터베이스)
- [모니터링](#모니터링)
- [개발 가이드](#개발-가이드)
- [문서](#문서)
- [주요 링크](#-주요-링크)
- [라이선스](#-라이선스)
- [팀](#-팀)
- [보고서](#보고서)
- [노션 협업일지](#-노션-협업일지)

## 🎯 프로젝트 개요

FeedlyAI는 다음과 같은 기능을 제공합니다:

- **이미지 분석**: VLM(Vision Language Model)을 사용한 이미지 분석 및 설명 생성
- **객체 감지**: YOLO를 활용한 이미지 내 객체 감지
- **레이아웃 계획**: AI 기반 텍스트/이미지 레이아웃 계획
- **이미지 생성**: 배경 생성 및 오버레이 이미지 생성
- **평가 시스템**: OCR, 가독성, IOU 등 다양한 평가 메트릭
- **광고 문구 생성**: LLM을 활용한 한국어 광고 문구 생성

## 🏗️ 아키텍처

### 서비스 구조

```
┌─────────────────────────────────────────────────────────┐
│                    NGINX (Reverse Proxy)                │
│                    Port: 8080                           │
│  /api/ye/ → app-ye  /api/yh/ → app-yh                   │
│  /api/js/ → app-js                                      │
│  /assets/ → Static Files                                │
└─────────────────────────────────────────────────────────┘
         │              │              │            
    ┌────┴────┐    ┌────┴────┐    ┌────┴────┐  
    │ app-ye  │    │ app-yh  │    │ app-js  │  
    │ 이미지    │    │ YOLO/   │    │ FE/BFF  │  
    │ 생성/    │    │ Planner │    │ Job     │  
    │ 분석     │    │ Eval    │    │ 제출     │   
    └────┬────┘    └────┬────┘    └────┬────┘   
         │              │              │        
         └──────────────┴──────────────┘
                          │
                  ┌───────┴────────┐
                  │   PostgreSQL    │
                  │   (공용/개별)   │
                  └─────────────────┘
```

### 주요 컴포넌트

- **NGINX**: 리버스 프록시 및 정적 파일 서빙
- **Application Services**: 3개의 마이크로서비스 (ye, yh, js)
- **PostgreSQL**: 공용 및 팀원별 데이터베이스 인스턴스
- **Adminer**: 데이터베이스 관리 도구
- **Prometheus + Grafana**: 모니터링 및 메트릭 수집

## 🚀 빠른 시작

### 사전 요구사항

- Docker & Docker Compose
- Python 3.11+ (개별 개발용)
- Git

### 1. 저장소 클론

```bash
git clone <repository-url>
cd feedlyai
```

### 2. 서브모듈 초기화

```bash
git submodule update --init --recursive
```

### 3. 환경 변수 설정

`.env` 파일을 생성하거나 수정합니다:

```bash
# NGINX 포트
PORT_NGINX=8080

# 서비스 포트
PORT_YE=8010
PORT_YH=8011
PORT_JS=8012

# 데이터베이스 설정
DB_NAME=feedlyai
DB_USER=feedlyai
DB_PASSWORD=feedlyai_password
DB_PORT=5432

# Assets 디렉토리
ASSETS_DIR=/opt/feedlyai/assets
```

### 4. Docker Compose로 서비스 시작

```bash
# 전체 서비스 시작
docker-compose up -d

# 특정 서비스만 시작
docker-compose up -d postgres nginx

# 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f
```

### 5. 서비스 접속

- **NGINX (통합 엔트리 포인트)**: http://localhost:8080
- **Adminer (DB 관리)**: http://localhost:8081
- **각 서비스 직접 접속**: http://localhost:${PORT_*}

## 🔧 서비스 구성

### app-ye: 이미지 생성/분석

- **역할**: 이미지 생성 및 VLM 기반 이미지 분석
- **포트**: `${PORT_YE}` (기본: 8010)
- **주요 기능**:
  - 배경 이미지 생성 (PBG - Photo Background Generation)
  - VLM을 활용한 이미지 분석 및 설명 생성
  - LLM 기반 프롬프트 생성

### app-yh: YOLO/Planner/Overlay/Eval/Judge

- **역할**: 객체 감지, 레이아웃 계획, 오버레이, 평가
- **포트**: `${PORT_YH}` (기본: 8011)
- **주요 기능**:
  - YOLO 기반 객체 감지
  - AI 기반 레이아웃 계획 (Planner)
  - 텍스트/이미지 오버레이
  - OCR 평가, 가독성 평가, IOU 평가
  - VLM 기반 최종 판단 (Judge)

### app-js: FE/BFF & 업로드/Job 제출

- **역할**: 프론트엔드, BFF, 파일 업로드, Job 관리
- **포트**: `${PORT_JS}` (기본: 8012)
- **주요 기능**:
  - 프론트엔드 서빙
  - Backend for Frontend (BFF)
  - 이미지 업로드 및 관리
  - Job 생성 및 상태 관리

## 💾 데이터베이스

### PostgreSQL 인스턴스

- **공용 DB**: `postgres` (포트: 5432)
- **팀원별 DB**:
  - `postgres-ye` (포트: 5434)
  - `postgres-yh` (포트: 5435)
  - `postgres-js` (포트: 5436)

### 데이터베이스 접속

```bash
# psql을 통한 접속
psql -h localhost -p 5432 -U feedlyai -d feedlyai

# Adminer를 통한 접속
# http://localhost:8081 (공용)
# http://localhost:8083 (ye)
# http://localhost:8084 (yh)
# http://localhost:8085 (js)
```

### 스키마 초기화

데이터베이스 스키마는 `db/init/` 디렉토리의 SQL 파일로 자동 초기화됩니다:

- `01_schema.sql`: 메인 스키마 정의
- `02_job_state_notify_trigger.sql`: Job 상태 변경 트리거
- `03_job_variants_state_notify_trigger.sql`: Job Variants 상태 변경 트리거

### 데이터베이스 문서

자세한 데이터베이스 가이드는 `docs/` 디렉토리를 참조하세요:

- `docs/DB_SETUP_GUIDE.md`: 데이터베이스 설정 가이드
- `docs/DB_USAGE_GUIDE.md`: 사용 가이드
- `docs/DB_QUICK_REFERENCE.md`: 빠른 참조

## 📊 모니터링

### Prometheus + Grafana

모니터링 스택은 별도의 `monitoring/` 디렉토리에서 관리됩니다.

```bash
cd monitoring
docker-compose up -d
```

- **Grafana**: http://localhost:3000 (기본 계정: `admin`/`admin`)
- **Prometheus**: http://localhost:9090

자세한 내용은 `monitoring/README.md`를 참조하세요.

## 👨‍💻 개발 가이드

### 서브모듈 업데이트

```bash
# 모든 서브모듈을 최신 main 브랜치로 업데이트
git submodule update --remote

# 변경사항 커밋 및 푸시
git add services/
git commit -m "Update submodules to latest main"
git push
```

### 개별 개발 환경 설정

각 팀원은 `team-template/`을 기반으로 개별 개발 환경을 구성할 수 있습니다.

자세한 내용은 각 서비스의 `README_template.md`를 참조하세요:

- `services/app-ye/README_TEMPLATE.md`
- `services/app-yh/README_TEMPLATE.md`
- `services/app-js/README_TEMPLATE.md`

### Job 삭제 스크립트

특정 Job과 관련된 모든 데이터를 삭제하는 스크립트:

```bash
python3 db/delete_job.py <job_id> [--force] [--dry-run]
```

예시:
```bash
python3 db/delete_job.py 79a0375c-1d54-4043-b71a-07eb42fffbfc --force
```

## 📚 문서

프로젝트의 상세 문서는 `docs/` 디렉토리에 있습니다:

- **데이터베이스**: `docs/DB_*.md`
- **포트 매핑**: `docs/PORT_MAPPING.md`
- **명령어 가이드**: `docs/COMMANDS.md`
- **모니터링**: `monitoring/README.md`
- **에셋 구조**: `docs/ASSETS_STRUCTURE.md`

## 🔗 주요 링크

- **NGINX (통합 엔트리)**: http://localhost:8080
- **Adminer (DB 관리)**: http://localhost:8081
- **Grafana (모니터링)**: http://localhost:3000
- **Prometheus**: http://localhost:9090

## 📝 라이선스

[라이선스 정보]

## 👥 팀

- **유영은**: 배경 이미지 생성/분석
- **이영호(팀장)**: DB(PostgreSQL,Adminer)/YOLO/Planner/Overlay/Eval/Judge/Serving/Monitoring(Grafana,Prometheus)
- **이종서**: FE/BFF & 업로드/Job 제출


## 보고서
https://drive.google.com/file/d/1lBN6lOK2-LNqV8nM9G1P9fP1Y2YncOWI

## 📑 노션 협업일지
팀 : https://www.notion.so/Codeit-AI-3-_-2-_-2a255af55ff680af835dde638729cb2d

유영은 : https://www.notion.so/Part4_2-_-Daily_-2a25954c5686809fbd40fa0ed83efdce

이영호 : https://www.notion.so/Codeit-AI-3-_-Part4_2-_-_-Daily_-2a255af55ff68048830fce21c4e7e8c7

이종서 : https://www.notion.so/2a264dd7ce72803abf1ac3d1d27942b7?v=2a264dd7ce7281de9f83000c117b0343

---

**참고**: 이 프로젝트는 Docker Compose를 사용하여 단일 VM에서 모든 서비스를 실행합니다. 프로덕션 환경에서는 각 서비스를 별도로 배포하는 것을 권장합니다.
