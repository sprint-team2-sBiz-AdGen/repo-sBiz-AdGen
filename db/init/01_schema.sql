-- FeedlyAI Database Schema
-- Version: 0.8
-- Created: 2025-11-16
-- Updated: 2025-11-25

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Set timezone to Korea (Asia/Seoul)
SET timezone = 'Asia/Seoul';

-- ============================================
-- 1. 핵심 엔티티 (Core Entities)
-- ============================================

-- USERS 테이블
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- TENANTS 테이블 (멀티테넌시)
CREATE TABLE IF NOT EXISTS tenants (
    tenant_id VARCHAR(255) PRIMARY KEY,
    display_name VARCHAR(255),
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- IMAGE_ASSETS 테이블
CREATE TABLE IF NOT EXISTS image_assets (
    image_asset_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    image_type VARCHAR(50),
    image_url TEXT NOT NULL,
    mask_url TEXT,
    width INTEGER,
    height INTEGER,
    creator_id UUID REFERENCES users(user_id),
    tenant_id VARCHAR(255) REFERENCES tenants(tenant_id),
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- STORES 테이블
CREATE TABLE IF NOT EXISTS stores (
    store_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    image_id UUID REFERENCES image_assets(image_asset_id),
    title VARCHAR(500),
    body TEXT,
    store_category TEXT,
    auto_scoring_flag BOOLEAN DEFAULT FALSE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2. 생성 모델 파이프라인 (Generative Models)
-- ============================================

-- TONE_STYLES 테이블
CREATE TABLE IF NOT EXISTS tone_styles (
    tone_style_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT,
    kor_name TEXT,
    eng_name TEXT,
    description TEXT,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- PBG_PROMPT_ASSETS 테이블
CREATE TABLE IF NOT EXISTS pbg_prompt_assets (
    prompt_asset_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tone_style_id UUID REFERENCES tone_styles(tone_style_id),
    prompt_type TEXT,
    prompt_version TEXT,
    prompt JSONB,
    negative_prompt JSONB,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- PBG_PLACEMENT_PRESETS 테이블
CREATE TABLE IF NOT EXISTS pbg_placement_presets (
    placement_preset_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prompt_type TEXT NOT NULL,  -- prompt_type으로 연결 (pbg_prompt_assets.prompt_type과 동일)
    preset_order INTEGER,  -- 같은 prompt_type 내에서의 순서
    x DECIMAL(5,4) NOT NULL,  -- 0.0 ~ 1.0
    y DECIMAL(5,4) NOT NULL,  -- 0.0 ~ 1.0
    size DECIMAL(5,4) NOT NULL,  -- 0.0 ~ 1.0
    rotation DECIMAL(5,2) NOT NULL DEFAULT 0.0,  -- 회전 각도
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- GEN_MODELS 테이블
CREATE TABLE IF NOT EXISTS gen_models (
    model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT,  -- Example: "Photo-Background-Generation"
    repo TEXT,  -- Example: "hf repo" (Hugging Face repository)
    version TEXT,
    defaults JSONB,  -- 파라미터들 값 (Parameters' values)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- GEN_RUNS 테이블
CREATE TABLE IF NOT EXISTS gen_runs (
    run_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES jobs(job_id),  -- FK
    tenant_id VARCHAR(255) REFERENCES tenants(tenant_id),  -- FK
    src_asset_id UUID REFERENCES image_assets(image_asset_id),  -- FK, 원본 이미지 (Original image)
    cutout_asset_id UUID REFERENCES image_assets(image_asset_id),  -- FK, 누끼 이미지 (Cutout image)
    model_id UUID REFERENCES gen_models(model_id),  -- FK, 사용 모델 (Used model)
    prompt_version TEXT,  -- FK, 사용 프롬프트 버전 (Used prompt version)
    bg_width INTEGER,  -- 이미지 가로 크기 (Image width)
    bg_height INTEGER,  -- 이미지 세로 크기 (Image height)
    status TEXT DEFAULT 'queued',  -- Possible values: queued/running/done/failed
    latency_ms FLOAT,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP WITH TIME ZONE  -- 상태가 done/failed 일때만 (Only when status is done/failed)
);

-- GEN_VARIANTS 테이블
CREATE TABLE IF NOT EXISTS gen_variants (
    gen_variant_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    run_id UUID REFERENCES gen_runs(run_id),  -- FK
    index INTEGER,  -- 같은 run 내에서 순번 (Sequence number within the same run)
    canvas_asset_id UUID REFERENCES image_assets(image_asset_id),  -- FK, 캔버스 이미지 id (Canvas image ID)
    mask_asset_id UUID REFERENCES image_assets(image_asset_id),  -- FK, 마스크 이미지 id (Mask image ID)
    bg_asset_id UUID REFERENCES image_assets(image_asset_id),  -- FK, 생성 이미지 id (Generated image ID)
    placement_preset_id UUID REFERENCES pbg_placement_presets(placement_preset_id),  -- FK, 피사체 위치/크기 (Subject position/size)
    prompt_en TEXT,  -- 프롬프트 (prompt)
    negative_en TEXT,  -- 네거티브 프롬프트 (Negative prompt)
    seed_base INTEGER DEFAULT 13,  -- 13 (일단 고정) (13 (fixed for now))
    steps INTEGER DEFAULT 20,  -- 20 (일단 고정) (20 (fixed for now))
    infer_ms FLOAT,  -- 추론시간(ms) (Inference time (ms))
    latency_ms FLOAT,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 3. Job 파이프라인 (Job Pipeline)
-- ============================================

-- JOBS 테이블
CREATE TABLE IF NOT EXISTS jobs (
    job_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(255) REFERENCES tenants(tenant_id),  -- FK
    store_id UUID,  -- FK (stores 테이블이 있다면 REFERENCES stores(store_id))
    status TEXT DEFAULT 'queued',  -- Possible values: queued, running, done, failed
    current_step TEXT,  -- Current pipeline step: 'vlm_analyze', 'vlm_planner', 'vlm_judge', 'llm_translate', 'llm_prompt', etc.
    version TEXT,
    retry_count INTEGER DEFAULT 0,  -- Job 재시도 횟수 (자동 복구 로직에 의해 증가)
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- JOB_INPUTS 테이블
CREATE TABLE IF NOT EXISTS job_inputs (
    job_id UUID PRIMARY KEY REFERENCES jobs(job_id),  -- PK, FK
    img_asset_id UUID REFERENCES image_assets(image_asset_id),  -- FK
    tone_style_id UUID REFERENCES tone_styles(tone_style_id),  -- FK
    desc_kor TEXT,
    desc_eng TEXT,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- JOBS_VARIANTS 테이블
CREATE TABLE IF NOT EXISTS jobs_variants (
    job_variants_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES jobs(job_id),  -- FK
    img_asset_id UUID REFERENCES image_assets(image_asset_id),  -- FK
    creation_order INTEGER NOT NULL,
    selected BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'queued',  -- queued, running, done, failed
    current_step TEXT DEFAULT 'vlm_analyze',  -- 'vlm_analyze', 'yolo_detect', 'planner', 'overlay', 'vlm_judge', 'ocr_eval', 'readability_eval', 'iou_eval'
    retry_count INTEGER DEFAULT 0,  -- Variant 재시도 횟수 (자동 복구 로직에 의해 증가)
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- VLM_PROMPT_ASSETS 테이블
CREATE TABLE IF NOT EXISTS vlm_prompt_assets (
    prompt_asset_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prompt_type TEXT,
    prompt_version TEXT,
    prompt JSONB,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- VLM_TRACES 테이블
CREATE TABLE IF NOT EXISTS vlm_traces (
    vlm_trace_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES jobs(job_id),  -- FK
    provider TEXT,  -- Example: 'llava'
    prompt_id UUID,  -- FK (pbg_prompt_assets 참조 가능)
    operation_type TEXT,  -- Possible values: analyze, planner, judge
    request JSONB,
    response JSONB,
    latency_ms FLOAT,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 4. AI 파이프라인 (app-yh 관련)
-- ============================================

-- DETECTIONS 테이블
CREATE TABLE IF NOT EXISTS detections (
    detection_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    image_asset_id UUID REFERENCES image_assets(image_asset_id),
    model_id UUID REFERENCES gen_models(model_id),
    job_id UUID REFERENCES jobs(job_id),
    box JSONB,  -- [x1, y1, x2, y2] 형식
    label VARCHAR(255),
    score DECIMAL(5,4),
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- YOLO_RUNS 테이블
CREATE TABLE IF NOT EXISTS yolo_runs (
    yolo_run_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID UNIQUE REFERENCES jobs(job_id),
    image_asset_id UUID REFERENCES image_assets(image_asset_id),
    forbidden_mask_url TEXT,
    model_name VARCHAR(255),
    detection_count INTEGER DEFAULT 0,
    latency_ms FLOAT,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- PLANNER_PROPOSALS 테이블
CREATE TABLE IF NOT EXISTS planner_proposals (
    proposal_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    image_asset_id UUID REFERENCES image_assets(image_asset_id),
    prompt TEXT,
    layout JSONB,  -- 레이아웃 정보
    latency_ms FLOAT,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- OVERLAY_LAYOUTS 테이블
CREATE TABLE IF NOT EXISTS overlay_layouts (
    overlay_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    proposal_id UUID REFERENCES planner_proposals(proposal_id),
    job_variants_id UUID REFERENCES jobs_variants(job_variants_id),  -- job_variants 연결
    layout JSONB,
    x_ratio DECIMAL(5,4),
    y_ratio DECIMAL(5,4),
    width_ratio DECIMAL(5,4),
    height_ratio DECIMAL(5,4),
    text_margin VARCHAR(50),
    latency_ms FLOAT,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- RENDERS 테이블
CREATE TABLE IF NOT EXISTS renders (
    render_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    overlay_id UUID REFERENCES overlay_layouts(overlay_id),
    image_asset_id UUID REFERENCES image_assets(image_asset_id),  -- 렌더링된 이미지
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- EVALUATIONS 테이블 (평가 결과 저장)
CREATE TABLE IF NOT EXISTS evaluations (
    evaluation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES jobs(job_id),  -- FK
    overlay_id UUID REFERENCES overlay_layouts(overlay_id),  -- FK
    evaluation_type VARCHAR(50) NOT NULL,  -- 'llava_judge', 'ocr', 'readability', 'iou'
    metrics JSONB NOT NULL,  -- 평가 메트릭 (타입별로 다른 구조)
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 5. LLM 통합 (LLM Integration)
-- ============================================

-- LLM_MODELS 테이블
CREATE TABLE IF NOT EXISTS llm_models (
    llm_model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 모델 기본 정보
    model_name VARCHAR(255) NOT NULL,  -- 모델 이름 (예: "gpt-4o-mini")
    model_version VARCHAR(255),  -- 모델 버전 (예: "2024-07-18")
    provider VARCHAR(255) NOT NULL,  -- 제공자 (예: "openai", "anthropic", "google")
    
    -- 모델 설정 (기본값)
    default_temperature FLOAT,  -- 기본 temperature 설정
    default_max_tokens INTEGER,  -- 기본 최대 토큰 수
    
    -- 비용 정보 (USD per 1M tokens)
    prompt_token_cost_per_1m FLOAT,  -- 입력 토큰당 비용 (per 1M tokens)
    completion_token_cost_per_1m FLOAT,  -- 출력 토큰당 비용 (per 1M tokens)
    
    -- 메타데이터
    description TEXT,  -- 모델 설명
    is_active VARCHAR(10) DEFAULT 'true',  -- 활성화 여부 ('true', 'false')
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- LLM_TRACES 테이블
CREATE TABLE IF NOT EXISTS llm_traces (
    llm_trace_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES jobs(job_id),  -- FK
    provider TEXT,  -- Example: 'gpt'
    tone_style_id UUID REFERENCES tone_styles(tone_style_id),  -- FK
    enhanced_img_id UUID REFERENCES image_assets(image_asset_id),  -- FK
    prompt_id UUID,  -- FK (pbg_prompt_assets 참조 가능)
    operation_type TEXT,  -- Possible values: translate, prompt
    request JSONB,
    response JSONB,
    latency_ms FLOAT,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. 인스타그램 피드 생성 (Instagram Feed Generation)
-- ============================================

-- INSTAGRAM_FEEDS 테이블 (리팩토링된 버전)
CREATE TABLE IF NOT EXISTS instagram_feeds (
    instagram_feed_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Foreign Keys
    job_id UUID REFERENCES jobs(job_id),  -- 파이프라인과 연결 시 사용
    overlay_id UUID REFERENCES overlay_layouts(overlay_id),  -- 오버레이 결과와 연결 시 사용
    llm_model_id UUID REFERENCES llm_models(llm_model_id),  -- 사용된 LLM 모델
    
    -- Tenant 정보
    tenant_id VARCHAR(255) NOT NULL,  -- 테넌트 ID
    
    -- 입력 데이터 (요청 시 받은 정보)
    refined_ad_copy_eng TEXT NOT NULL,  -- 조정된 광고문구 (영어)
    tone_style TEXT NOT NULL,  -- 톤 & 스타일
    product_description TEXT NOT NULL,  -- 제품 설명
    store_information TEXT NOT NULL,  -- 스토어 정보
    gpt_prompt TEXT NOT NULL,  -- GPT 프롬프트
    
    -- 출력 데이터 (생성된 결과)
    instagram_ad_copy TEXT NOT NULL,  -- 생성된 인스타그램 피드 글
    hashtags TEXT NOT NULL,  -- 생성된 해시태그 (예: "#태그1 #태그2 #태그3")
    
    -- LLM 실행 메타데이터 (실제 실행 시 사용된 값)
    used_temperature FLOAT,  -- 실제 사용된 temperature (llm_models의 기본값과 다를 수 있음)
    used_max_tokens INTEGER,  -- 실제 사용된 최대 토큰 수
    gpt_prompt_used TEXT,  -- 실제 사용된 전체 프롬프트 (디버깅용)
    gpt_response_raw JSONB,  -- GPT API 원본 응답 (디버깅/재생성용)
    
    -- 성능 메트릭
    latency_ms FLOAT,  -- GPT API 호출 소요 시간 (밀리초)
    prompt_tokens INTEGER,  -- 프롬프트 토큰 수 (입력, 모니터링용)
    completion_tokens INTEGER,  -- 생성 토큰 수 (출력, 모니터링용)
    total_tokens INTEGER,  -- 총 토큰 수 (모니터링용)
    token_usage JSONB,  -- 토큰 사용량 정보 원본 (예: {"prompt_tokens": 100, "completion_tokens": 200, "total_tokens": 300})
    
    -- 메타데이터
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 7. 시스템 이벤트 (System Events)
-- ============================================

-- WORKER_EVENTS 테이블
CREATE TABLE IF NOT EXISTS worker_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(100),
    status VARCHAR(50),
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- CONNECTED_NODES 테이블
CREATE TABLE IF NOT EXISTS connected_nodes (
    node_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_type VARCHAR(100),
    status VARCHAR(50),
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 인덱스 생성
-- ============================================

-- Foreign Key 인덱스
CREATE INDEX IF NOT EXISTS idx_image_assets_creator_id ON image_assets(creator_id);
CREATE INDEX IF NOT EXISTS idx_image_assets_tenant_id ON image_assets(tenant_id);
CREATE INDEX IF NOT EXISTS idx_stores_user_id ON stores(user_id);
CREATE INDEX IF NOT EXISTS idx_stores_image_id ON stores(image_id);
CREATE INDEX IF NOT EXISTS idx_gen_runs_job_id ON gen_runs(job_id);
CREATE INDEX IF NOT EXISTS idx_gen_runs_tenant_id ON gen_runs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_gen_runs_model_id ON gen_runs(model_id);
CREATE INDEX IF NOT EXISTS idx_gen_runs_src_asset_id ON gen_runs(src_asset_id);
CREATE INDEX IF NOT EXISTS idx_gen_runs_cutout_asset_id ON gen_runs(cutout_asset_id);
CREATE INDEX IF NOT EXISTS idx_gen_runs_status ON gen_runs(status);
CREATE INDEX IF NOT EXISTS idx_gen_variants_run_id ON gen_variants(run_id);
CREATE INDEX IF NOT EXISTS idx_gen_variants_run_id_index ON gen_variants(run_id, index);
CREATE INDEX IF NOT EXISTS idx_gen_variants_canvas_asset_id ON gen_variants(canvas_asset_id);
CREATE INDEX IF NOT EXISTS idx_gen_variants_mask_asset_id ON gen_variants(mask_asset_id);
CREATE INDEX IF NOT EXISTS idx_gen_variants_bg_asset_id ON gen_variants(bg_asset_id);
CREATE INDEX IF NOT EXISTS idx_gen_variants_placement_preset_id ON gen_variants(placement_preset_id);
CREATE INDEX IF NOT EXISTS idx_detections_image_id ON detections(image_asset_id);
CREATE INDEX IF NOT EXISTS idx_detections_job_id ON detections(job_id);
CREATE INDEX IF NOT EXISTS idx_yolo_runs_job_id ON yolo_runs(job_id);
CREATE INDEX IF NOT EXISTS idx_yolo_runs_image_asset_id ON yolo_runs(image_asset_id);
CREATE INDEX IF NOT EXISTS idx_planner_proposals_image_id ON planner_proposals(image_asset_id);
CREATE INDEX IF NOT EXISTS idx_overlay_layouts_proposal_id ON overlay_layouts(proposal_id);
CREATE INDEX IF NOT EXISTS idx_overlay_layouts_job_variants_id ON overlay_layouts(job_variants_id);
CREATE INDEX IF NOT EXISTS idx_renders_overlay_id ON renders(overlay_id);
CREATE INDEX IF NOT EXISTS idx_evaluations_job_id ON evaluations(job_id);
CREATE INDEX IF NOT EXISTS idx_evaluations_overlay_id ON evaluations(overlay_id);
CREATE INDEX IF NOT EXISTS idx_evaluations_type ON evaluations(evaluation_type);
CREATE INDEX IF NOT EXISTS idx_pbg_prompt_assets_tone_style_id ON pbg_prompt_assets(tone_style_id);
CREATE INDEX IF NOT EXISTS idx_vlm_prompt_assets_prompt_type ON vlm_prompt_assets(prompt_type);
CREATE INDEX IF NOT EXISTS idx_pbg_placement_presets_prompt_type ON pbg_placement_presets(prompt_type);
CREATE INDEX IF NOT EXISTS idx_pbg_placement_presets_prompt_type_order ON pbg_placement_presets(prompt_type, preset_order);
CREATE INDEX IF NOT EXISTS idx_jobs_tenant_id ON jobs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_jobs_store_id ON jobs(store_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_current_step ON jobs(current_step);
CREATE INDEX IF NOT EXISTS idx_jobs_retry_count ON jobs(retry_count);
CREATE INDEX IF NOT EXISTS idx_jobs_status_retry_count ON jobs(status, retry_count);
CREATE INDEX IF NOT EXISTS idx_job_inputs_img_asset_id ON job_inputs(img_asset_id);
CREATE INDEX IF NOT EXISTS idx_job_inputs_tone_style_id ON job_inputs(tone_style_id);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_job_id ON jobs_variants(job_id);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_img_asset_id ON jobs_variants(img_asset_id);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_creation_order ON jobs_variants(creation_order);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_selected ON jobs_variants(selected);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_status ON jobs_variants(status);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_current_step ON jobs_variants(current_step);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_job_id_status ON jobs_variants(job_id, status);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_retry_count ON jobs_variants(retry_count);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_status_retry_count ON jobs_variants(status, retry_count);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_job_id_retry_count ON jobs_variants(job_id, retry_count);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_job_id ON vlm_traces(job_id);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_prompt_id ON vlm_traces(prompt_id);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_operation_type ON vlm_traces(operation_type);
CREATE INDEX IF NOT EXISTS idx_llm_traces_job_id ON llm_traces(job_id);
CREATE INDEX IF NOT EXISTS idx_llm_traces_tone_style_id ON llm_traces(tone_style_id);
CREATE INDEX IF NOT EXISTS idx_llm_traces_enhanced_img_id ON llm_traces(enhanced_img_id);
CREATE INDEX IF NOT EXISTS idx_llm_traces_prompt_id ON llm_traces(prompt_id);
CREATE INDEX IF NOT EXISTS idx_llm_traces_operation_type ON llm_traces(operation_type);
CREATE INDEX IF NOT EXISTS idx_llm_models_provider ON llm_models(provider);
CREATE INDEX IF NOT EXISTS idx_llm_models_model_name ON llm_models(model_name);
CREATE INDEX IF NOT EXISTS idx_llm_models_is_active ON llm_models(is_active);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_job_id ON instagram_feeds(job_id);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_overlay_id ON instagram_feeds(overlay_id);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_llm_model_id ON instagram_feeds(llm_model_id);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_tenant_id ON instagram_feeds(tenant_id);

-- 시간 기반 인덱스 (조회 성능 향상)
CREATE INDEX IF NOT EXISTS idx_image_assets_created_at ON image_assets(created_at);
CREATE INDEX IF NOT EXISTS idx_stores_created_at ON stores(created_at);
CREATE INDEX IF NOT EXISTS idx_gen_runs_created_at ON gen_runs(created_at);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_job_inputs_created_at ON job_inputs(created_at);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_created_at ON jobs_variants(created_at);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_created_at ON vlm_traces(created_at);
CREATE INDEX IF NOT EXISTS idx_llm_traces_created_at ON llm_traces(created_at);
CREATE INDEX IF NOT EXISTS idx_evaluations_created_at ON evaluations(created_at);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_created_at ON instagram_feeds(created_at);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_prompt_tokens ON instagram_feeds(prompt_tokens);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_completion_tokens ON instagram_feeds(completion_tokens);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_total_tokens ON instagram_feeds(total_tokens);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_created_at_tokens ON instagram_feeds(created_at, total_tokens);

-- JSONB 인덱스 (GIN 인덱스)
CREATE INDEX IF NOT EXISTS idx_detections_box ON detections USING GIN (box);
CREATE INDEX IF NOT EXISTS idx_planner_proposals_layout ON planner_proposals USING GIN (layout);
CREATE INDEX IF NOT EXISTS idx_evaluations_metrics ON evaluations USING GIN (metrics);
CREATE INDEX IF NOT EXISTS idx_pbg_prompt_assets_prompt ON pbg_prompt_assets USING GIN (prompt);
CREATE INDEX IF NOT EXISTS idx_pbg_prompt_assets_negative_prompt ON pbg_prompt_assets USING GIN (negative_prompt);
CREATE INDEX IF NOT EXISTS idx_vlm_prompt_assets_prompt ON vlm_prompt_assets USING GIN (prompt);
CREATE INDEX IF NOT EXISTS idx_gen_models_defaults ON gen_models USING GIN (defaults);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_request ON vlm_traces USING GIN (request);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_response ON vlm_traces USING GIN (response);
CREATE INDEX IF NOT EXISTS idx_llm_traces_request ON llm_traces USING GIN (request);
CREATE INDEX IF NOT EXISTS idx_llm_traces_response ON llm_traces USING GIN (response);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_gpt_response_raw ON instagram_feeds USING GIN (gpt_response_raw);
CREATE INDEX IF NOT EXISTS idx_instagram_feeds_token_usage ON instagram_feeds USING GIN (token_usage);




