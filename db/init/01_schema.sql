-- FeedlyAI Database Schema
-- Version: 0.7
-- Created: 2025-11-16
-- Updated: 2025-11-24

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
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- STORIES 테이블
CREATE TABLE IF NOT EXISTS stories (
    story_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    image_id UUID REFERENCES image_assets(image_asset_id),
    title VARCHAR(500),
    body TEXT,
    auto_scoring_flag BOOLEAN DEFAULT FALSE,
    uid VARCHAR(255) UNIQUE,
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
    uid VARCHAR(255) UNIQUE,
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
    uid VARCHAR(255) UNIQUE,
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
    uid VARCHAR(255) UNIQUE,
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
    tenant_id VARCHAR(255) REFERENCES tenants(tenant_id),  -- FK
    src_asset_id UUID REFERENCES image_assets(image_asset_id),  -- FK, 원본 이미지 (Original image)
    cutout_asset_id UUID REFERENCES image_assets(image_asset_id),  -- FK, 누끼 이미지 (Cutout image)
    model_id UUID REFERENCES gen_models(model_id),  -- FK, 사용 모델 (Used model)
    prompt_version TEXT,  -- FK, 사용 프롬프트 버전 (Used prompt version)
    bg_width INTEGER,  -- 이미지 가로 크기 (Image width)
    bg_height INTEGER,  -- 이미지 세로 크기 (Image height)
    status TEXT DEFAULT 'queued',  -- Possible values: queued/running/done/failed
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- JOBS_VARIANTS 테이블
CREATE TABLE IF NOT EXISTS jobs_variants (
    job_variants_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES jobs(job_id),  -- FK
    img_asset_id UUID REFERENCES image_assets(image_asset_id),  -- FK
    rank INTEGER,
    selected BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- VLM_PROMPT_ASSETS 테이블
CREATE TABLE IF NOT EXISTS vlm_prompt_assets (
    prompt_asset_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prompt_type TEXT,
    prompt_version TEXT,
    prompt JSONB,
    uid VARCHAR(255) UNIQUE,
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
    uid VARCHAR(255) UNIQUE,
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- PLANNER_PROPOSALS 테이블
CREATE TABLE IF NOT EXISTS planner_proposals (
    proposal_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    image_asset_id UUID REFERENCES image_assets(image_asset_id),
    prompt TEXT,
    layout JSONB,  -- 레이아웃 정보
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- OVERLAY_LAYOUTS 테이블
CREATE TABLE IF NOT EXISTS overlay_layouts (
    overlay_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    proposal_id UUID REFERENCES planner_proposals(proposal_id),
    layout JSONB,
    x_ratio DECIMAL(5,4),
    y_ratio DECIMAL(5,4),
    width_ratio DECIMAL(5,4),
    height_ratio DECIMAL(5,4),
    text_margin VARCHAR(50),
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- RENDERS 테이블
CREATE TABLE IF NOT EXISTS renders (
    render_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    overlay_id UUID REFERENCES overlay_layouts(overlay_id),
    image_asset_id UUID REFERENCES image_assets(image_asset_id),  -- 렌더링된 이미지
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- EVALS 테이블
CREATE TABLE IF NOT EXISTS evals (
    eval_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    render_id UUID REFERENCES renders(render_id),
    score JSONB,  -- 다양한 평가 점수들
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- JUDGE_RESULTS 테이블
CREATE TABLE IF NOT EXISTS judge_results (
    judge_result_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    eval_id UUID REFERENCES evals(eval_id),
    issue JSONB,  -- 이슈 정보
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 5. LLM 통합 (LLM Integration)
-- ============================================

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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. 시스템 이벤트 (System Events)
-- ============================================

-- WORKER_EVENTS 테이블
CREATE TABLE IF NOT EXISTS worker_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(100),
    status VARCHAR(50),
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- CONNECTED_NODES 테이블
CREATE TABLE IF NOT EXISTS connected_nodes (
    node_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_type VARCHAR(100),
    status VARCHAR(50),
    uid VARCHAR(255) UNIQUE,
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
CREATE INDEX IF NOT EXISTS idx_stories_user_id ON stories(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_image_id ON stories(image_id);
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
CREATE INDEX IF NOT EXISTS idx_renders_overlay_id ON renders(overlay_id);
CREATE INDEX IF NOT EXISTS idx_evals_render_id ON evals(render_id);
CREATE INDEX IF NOT EXISTS idx_judge_results_eval_id ON judge_results(eval_id);
CREATE INDEX IF NOT EXISTS idx_pbg_prompt_assets_tone_style_id ON pbg_prompt_assets(tone_style_id);
CREATE INDEX IF NOT EXISTS idx_vlm_prompt_assets_prompt_type ON vlm_prompt_assets(prompt_type);
CREATE INDEX IF NOT EXISTS idx_pbg_placement_presets_prompt_type ON pbg_placement_presets(prompt_type);
CREATE INDEX IF NOT EXISTS idx_pbg_placement_presets_prompt_type_order ON pbg_placement_presets(prompt_type, preset_order);
CREATE INDEX IF NOT EXISTS idx_jobs_tenant_id ON jobs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_jobs_store_id ON jobs(store_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_current_step ON jobs(current_step);
CREATE INDEX IF NOT EXISTS idx_job_inputs_img_asset_id ON job_inputs(img_asset_id);
CREATE INDEX IF NOT EXISTS idx_job_inputs_tone_style_id ON job_inputs(tone_style_id);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_job_id ON jobs_variants(job_id);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_img_asset_id ON jobs_variants(img_asset_id);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_rank ON jobs_variants(rank);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_selected ON jobs_variants(selected);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_job_id ON vlm_traces(job_id);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_prompt_id ON vlm_traces(prompt_id);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_operation_type ON vlm_traces(operation_type);
CREATE INDEX IF NOT EXISTS idx_llm_traces_job_id ON llm_traces(job_id);
CREATE INDEX IF NOT EXISTS idx_llm_traces_tone_style_id ON llm_traces(tone_style_id);
CREATE INDEX IF NOT EXISTS idx_llm_traces_enhanced_img_id ON llm_traces(enhanced_img_id);
CREATE INDEX IF NOT EXISTS idx_llm_traces_prompt_id ON llm_traces(prompt_id);
CREATE INDEX IF NOT EXISTS idx_llm_traces_operation_type ON llm_traces(operation_type);

-- 시간 기반 인덱스 (조회 성능 향상)
CREATE INDEX IF NOT EXISTS idx_image_assets_created_at ON image_assets(created_at);
CREATE INDEX IF NOT EXISTS idx_stories_created_at ON stories(created_at);
CREATE INDEX IF NOT EXISTS idx_gen_runs_created_at ON gen_runs(created_at);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_job_inputs_created_at ON job_inputs(created_at);
CREATE INDEX IF NOT EXISTS idx_jobs_variants_created_at ON jobs_variants(created_at);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_created_at ON vlm_traces(created_at);
CREATE INDEX IF NOT EXISTS idx_llm_traces_created_at ON llm_traces(created_at);

-- JSONB 인덱스 (GIN 인덱스)
CREATE INDEX IF NOT EXISTS idx_detections_box ON detections USING GIN (box);
CREATE INDEX IF NOT EXISTS idx_planner_proposals_layout ON planner_proposals USING GIN (layout);
CREATE INDEX IF NOT EXISTS idx_evals_score ON evals USING GIN (score);
CREATE INDEX IF NOT EXISTS idx_pbg_prompt_assets_prompt ON pbg_prompt_assets USING GIN (prompt);
CREATE INDEX IF NOT EXISTS idx_pbg_prompt_assets_negative_prompt ON pbg_prompt_assets USING GIN (negative_prompt);
CREATE INDEX IF NOT EXISTS idx_vlm_prompt_assets_prompt ON vlm_prompt_assets USING GIN (prompt);
CREATE INDEX IF NOT EXISTS idx_gen_models_defaults ON gen_models USING GIN (defaults);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_request ON vlm_traces USING GIN (request);
CREATE INDEX IF NOT EXISTS idx_vlm_traces_response ON vlm_traces USING GIN (response);
CREATE INDEX IF NOT EXISTS idx_llm_traces_request ON llm_traces USING GIN (request);
CREATE INDEX IF NOT EXISTS idx_llm_traces_response ON llm_traces USING GIN (response);




