-- FeedlyAI 테스트 데이터 삽입 SQL
-- 테스트 및 개발용 샘플 데이터

-- ============================================
-- 1. 기본 데이터 삽입
-- ============================================

-- 사용자 생성
INSERT INTO users (user_id, uid) VALUES
    ('550e8400-e29b-41d4-a716-446655440000', 'user001'),
    ('550e8400-e29b-41d4-a716-446655440001', 'user002')
ON CONFLICT (user_id) DO NOTHING;

-- 테넌트 생성
INSERT INTO tenants (tenant_id, display_name, uid) VALUES
    ('tenant01', '테스트 테넌트 1', 'tenant01'),
    ('tenant02', '테스트 테넌트 2', 'tenant02')
ON CONFLICT (tenant_id) DO NOTHING;

-- 이미지 에셋 생성
INSERT INTO image_assets (image_asset_id, image_type, image_url, width, height, creator_id, tenant_id, uid) VALUES
    ('660e8400-e29b-41d4-a716-446655440000', 'original', '/assets/yh/test/image1.jpg', 1920, 1080, '550e8400-e29b-41d4-a716-446655440000', 'tenant01', 'img001'),
    ('660e8400-e29b-41d4-a716-446655440001', 'original', '/assets/yh/test/image2.jpg', 1280, 720, '550e8400-e29b-41d4-a716-446655440000', 'tenant01', 'img002'),
    ('660e8400-e29b-41d4-a716-446655440002', 'generated', '/assets/yh/test/generated1.png', 1920, 1080, '550e8400-e29b-41d4-a716-446655440001', 'tenant02', 'img003')
ON CONFLICT (image_asset_id) DO NOTHING;

-- 스토리 생성
INSERT INTO stories (story_id, user_id, image_id, title, body, auto_scoring_flag, uid) VALUES
    ('770e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', '테스트 스토리 1', '이것은 테스트 스토리입니다.', true, 'story001'),
    ('770e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440001', '테스트 스토리 2', '두 번째 테스트 스토리입니다.', false, 'story002')
ON CONFLICT (story_id) DO NOTHING;

-- ============================================
-- 2. 생성 모델 데이터
-- ============================================

-- 생성 모델
INSERT INTO gen_models (gen_model_id, model_name, model_type, description, uid) VALUES
    ('880e8400-e29b-41d4-a716-446655440000', 'Stable Diffusion v2.1', 'text-to-image', '텍스트에서 이미지 생성 모델', 'model001'),
    ('880e8400-e29b-41d4-a716-446655440001', 'DALL-E 3', 'text-to-image', 'OpenAI 이미지 생성 모델', 'model002')
ON CONFLICT (gen_model_id) DO NOTHING;

-- 생성 실행
INSERT INTO gen_runs (gen_run_id, gen_model_id, image_id, prompt, negative_prompt, num_images, steps, cfg_scale, sampler, seed, uid) VALUES
    ('990e8400-e29b-41d4-a716-446655440000', '880e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440002', 'delicious korean food, professional photography', 'blurry, low quality', 3, 50, 7.5, 'DDIM', 12345, 'run001')
ON CONFLICT (gen_run_id) DO NOTHING;

-- 생성 변형
INSERT INTO gen_variants (gen_variant_id, gen_run_id, image_id, variant_type, uid) VALUES
    ('aa0e8400-e29b-41d4-a716-446655440000', '990e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440002', 'original', 'variant001')
ON CONFLICT (gen_variant_id) DO NOTHING;

-- ============================================
-- 3. AI 파이프라인 데이터 (app-yh)
-- ============================================

-- Detection 결과
INSERT INTO detections (detection_id, image_asset_id, model_id, box, label, score, uid) VALUES
    ('bb0e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', '880e8400-e29b-41d4-a716-446655440000', '[960, 540, 1440, 810]'::jsonb, 'forbidden', 0.95, 'det001'),
    ('bb0e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440001', '880e8400-e29b-41d4-a716-446655440000', '[640, 180, 1280, 540]'::jsonb, 'food', 0.88, 'det002')
ON CONFLICT (detection_id) DO NOTHING;

-- Planner Proposal
INSERT INTO planner_proposals (proposal_id, image_asset_id, prompt, layout, uid) VALUES
    ('cc0e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', '오늘만 특가!', '{"position": "top", "width": 0.8, "height": 0.18}'::jsonb, 'prop001'),
    ('cc0e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440001', '신메뉴 출시', '{"position": "center", "width": 0.6, "height": 0.2}'::jsonb, 'prop002')
ON CONFLICT (proposal_id) DO NOTHING;

-- Overlay Layout
INSERT INTO overlay_layouts (overlay_id, proposal_id, layout, x_ratio, y_ratio, width_ratio, height_ratio, text_margin, uid) VALUES
    ('dd0e8400-e29b-41d4-a716-446655440000', 'cc0e8400-e29b-41d4-a716-446655440000', '{"text": "오늘만 특가!", "color": "#FFFFFF", "bg_color": "#00000080"}'::jsonb, 0.1, 0.05, 0.8, 0.18, '8px', 'overlay001'),
    ('dd0e8400-e29b-41d4-a716-446655440001', 'cc0e8400-e29b-41d4-a716-446655440001', '{"text": "신메뉴 출시", "color": "#FF0000", "bg_color": "#FFFFFF80"}'::jsonb, 0.2, 0.4, 0.6, 0.2, '12px', 'overlay002')
ON CONFLICT (overlay_id) DO NOTHING;

-- Render
INSERT INTO renders (render_id, overlay_id, image_asset_id, uid) VALUES
    ('ee0e8400-e29b-41d4-a716-446655440000', 'dd0e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', 'render001'),
    ('ee0e8400-e29b-41d4-a716-446655440001', 'dd0e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440001', 'render002')
ON CONFLICT (render_id) DO NOTHING;

-- Eval
INSERT INTO evals (eval_id, render_id, score, uid) VALUES
    ('ff0e8400-e29b-41d4-a716-446655440000', 'ee0e8400-e29b-41d4-a716-446655440000', '{"ocr_conf": 0.95, "text_ratio": 0.15, "clip_score": 0.85, "iou_forbidden": 0.0, "gate_pass": true}'::jsonb, 'eval001'),
    ('ff0e8400-e29b-41d4-a716-446655440001', 'ee0e8400-e29b-41d4-a716-446655440001', '{"ocr_conf": 0.92, "text_ratio": 0.12, "clip_score": 0.78, "iou_forbidden": 0.0, "gate_pass": true}'::jsonb, 'eval002')
ON CONFLICT (eval_id) DO NOTHING;

-- Judge Results
INSERT INTO judge_results (judge_result_id, eval_id, issue, uid) VALUES
    ('110e8400-e29b-41d4-a716-446655440000', 'ff0e8400-e29b-41d4-a716-446655440000', '{"on_brief": true, "occlusion": false, "contrast_ok": true, "cta_present": true, "issues": []}'::jsonb, 'judge001'),
    ('110e8400-e29b-41d4-a716-446655440001', 'ff0e8400-e29b-41d4-a716-446655440001', '{"on_brief": true, "occlusion": false, "contrast_ok": true, "cta_present": true, "issues": []}'::jsonb, 'judge002')
ON CONFLICT (judge_result_id) DO NOTHING;

-- ============================================
-- 4. LLM 통합 데이터
-- ============================================

-- LLM Image
INSERT INTO llm_image (llm_image_id, image_id, prompt, uid) VALUES
    ('220e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', '이 이미지를 분석하고 마케팅 문구를 제안해주세요', 'llm_img001')
ON CONFLICT (llm_image_id) DO NOTHING;

-- LLM Traces
INSERT INTO llm_traces (llm_trace_id, llm_image_id, response, uid) VALUES
    ('330e8400-e29b-41d4-a716-446655440000', '220e8400-e29b-41d4-a716-446655440000', '{"suggestions": ["오늘만 특가!", "신메뉴 출시", "맛있는 한식"], "reasoning": "이미지에 음식이 보이므로 음식 관련 문구를 제안합니다."}'::jsonb, 'trace001')
ON CONFLICT (llm_trace_id) DO NOTHING;

-- ============================================
-- 5. 시스템 이벤트
-- ============================================

-- Worker Events
INSERT INTO worker_events (event_id, event_type, status, start_time, end_time, uid) VALUES
    ('440e8400-e29b-41d4-a716-446655440000', 'detection', 'completed', NOW() - INTERVAL '10 minutes', NOW() - INTERVAL '9 minutes', 'event001'),
    ('440e8400-e29b-41d4-a716-446655440001', 'overlay', 'completed', NOW() - INTERVAL '5 minutes', NOW() - INTERVAL '4 minutes', 'event002')
ON CONFLICT (event_id) DO NOTHING;

-- Connected Nodes
INSERT INTO connected_nodes (node_id, node_type, status, uid) VALUES
    ('550e8400-e29b-41d4-a716-446655440010', 'app-yh', 'active', 'node001'),
    ('550e8400-e29b-41d4-a716-446655440011', 'app-ye', 'active', 'node002')
ON CONFLICT (node_id) DO NOTHING;

