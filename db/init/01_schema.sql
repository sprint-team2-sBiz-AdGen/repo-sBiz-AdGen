-- FeedlyAI Database Schema
-- Version: 0.7
-- Created: 2025-11-16

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

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

-- GEN_MODELS 테이블
CREATE TABLE IF NOT EXISTS gen_models (
    gen_model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_name VARCHAR(255) NOT NULL,
    model_type VARCHAR(100),
    description TEXT,
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- GEN_RUNS 테이블
CREATE TABLE IF NOT EXISTS gen_runs (
    gen_run_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    gen_model_id UUID REFERENCES gen_models(gen_model_id),
    image_id UUID REFERENCES image_assets(image_asset_id),
    prompt TEXT,
    negative_prompt TEXT,
    num_images INTEGER DEFAULT 1,
    steps INTEGER,
    cfg_scale DECIMAL(5,2),
    sampler VARCHAR(100),
    seed INTEGER,
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- GEN_VARIANTS 테이블
CREATE TABLE IF NOT EXISTS gen_variants (
    gen_variant_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    gen_run_id UUID REFERENCES gen_runs(gen_run_id),
    image_id UUID REFERENCES image_assets(image_asset_id),
    variant_type VARCHAR(100),
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 3. AI 파이프라인 (app-yh 관련)
-- ============================================

-- DETECTIONS 테이블
CREATE TABLE IF NOT EXISTS detections (
    detection_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    image_asset_id UUID REFERENCES image_assets(image_asset_id),
    model_id UUID REFERENCES gen_models(gen_model_id),
    box JSONB,  -- [x1, y1, x2, y2] 형식
    label VARCHAR(255),
    score DECIMAL(5,4),
    uid VARCHAR(255) UNIQUE,
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
-- 4. LLM 통합 (LLM Integration)
-- ============================================

-- LLM_IMAGE 테이블
CREATE TABLE IF NOT EXISTS llm_image (
    llm_image_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    image_id UUID REFERENCES image_assets(image_asset_id),
    prompt TEXT,
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- LLM_VARIANTS 테이블
CREATE TABLE IF NOT EXISTS llm_variants (
    llm_variant_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    llm_image_id UUID REFERENCES llm_image(llm_image_id),
    variant_id UUID,  -- GEN_VARIANTS 참조 가능
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- LLM_TRACES 테이블
CREATE TABLE IF NOT EXISTS llm_traces (
    llm_trace_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    llm_image_id UUID REFERENCES llm_image(llm_image_id),
    response JSONB,  -- LLM 응답
    uid VARCHAR(255) UNIQUE,
    pk SERIAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 5. 시스템 이벤트 (System Events)
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
CREATE INDEX IF NOT EXISTS idx_gen_runs_model_id ON gen_runs(gen_model_id);
CREATE INDEX IF NOT EXISTS idx_gen_runs_image_id ON gen_runs(image_id);
CREATE INDEX IF NOT EXISTS idx_detections_image_id ON detections(image_asset_id);
CREATE INDEX IF NOT EXISTS idx_planner_proposals_image_id ON planner_proposals(image_asset_id);
CREATE INDEX IF NOT EXISTS idx_overlay_layouts_proposal_id ON overlay_layouts(proposal_id);
CREATE INDEX IF NOT EXISTS idx_renders_overlay_id ON renders(overlay_id);
CREATE INDEX IF NOT EXISTS idx_evals_render_id ON evals(render_id);
CREATE INDEX IF NOT EXISTS idx_judge_results_eval_id ON judge_results(eval_id);

-- 시간 기반 인덱스 (조회 성능 향상)
CREATE INDEX IF NOT EXISTS idx_image_assets_created_at ON image_assets(created_at);
CREATE INDEX IF NOT EXISTS idx_stories_created_at ON stories(created_at);
CREATE INDEX IF NOT EXISTS idx_gen_runs_created_at ON gen_runs(created_at);

-- JSONB 인덱스 (GIN 인덱스)
CREATE INDEX IF NOT EXISTS idx_detections_box ON detections USING GIN (box);
CREATE INDEX IF NOT EXISTS idx_planner_proposals_layout ON planner_proposals USING GIN (layout);
CREATE INDEX IF NOT EXISTS idx_evals_score ON evals USING GIN (score);




