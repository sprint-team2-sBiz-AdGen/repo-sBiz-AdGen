-- FeedlyAI 테스트 쿼리 모음
-- 다양한 시나리오별 쿼리 예시

-- ============================================
-- 1. 기본 조회 쿼리
-- ============================================

-- 모든 사용자 조회
SELECT user_id, uid, created_at FROM users ORDER BY created_at DESC;

-- 모든 테넌트 조회
SELECT tenant_id, display_name FROM tenants;

-- 모든 이미지 에셋 조회
SELECT 
    image_asset_id,
    image_type,
    image_url,
    width,
    height,
    tenant_id,
    created_at
FROM image_assets
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- 2. JOIN 쿼리
-- ============================================

-- 이미지와 사용자 정보 함께 조회
SELECT 
    ia.image_asset_id,
    ia.image_url,
    ia.width,
    ia.height,
    u.uid as creator_uid,
    t.display_name as tenant_name
FROM image_assets ia
LEFT JOIN users u ON ia.creator_id = u.user_id
LEFT JOIN tenants t ON ia.tenant_id = t.tenant_id
ORDER BY ia.created_at DESC;

-- 스토리와 관련 이미지 정보
SELECT 
    s.story_id,
    s.title,
    s.body,
    u.uid as author_uid,
    ia.image_url,
    ia.width,
    ia.height
FROM stories s
JOIN users u ON s.user_id = u.user_id
JOIN image_assets ia ON s.image_id = ia.image_asset_id
ORDER BY s.created_at DESC;

-- ============================================
-- 3. AI 파이프라인 전체 조회 (app-yh)
-- ============================================

-- Detection부터 Judge까지 전체 파이프라인 조회
SELECT 
    ia.image_url as original_image,
    d.box as detection_box,
    d.label as detection_label,
    d.score as detection_score,
    pp.prompt as proposal_prompt,
    ol.x_ratio,
    ol.y_ratio,
    r.image_asset_id as render_id,
    e.score as eval_score,
    jr.issue as judge_issue
FROM image_assets ia
LEFT JOIN detections d ON ia.image_asset_id = d.image_asset_id
LEFT JOIN planner_proposals pp ON ia.image_asset_id = pp.image_asset_id
LEFT JOIN overlay_layouts ol ON pp.proposal_id = ol.proposal_id
LEFT JOIN renders r ON ol.overlay_id = r.overlay_id
LEFT JOIN evals e ON r.render_id = e.render_id
LEFT JOIN judge_results jr ON e.eval_id = jr.eval_id
WHERE ia.tenant_id = 'tenant01'
ORDER BY ia.created_at DESC;

-- ============================================
-- 4. JSONB 필드 쿼리
-- ============================================

-- Detection의 box 정보 조회
SELECT 
    detection_id,
    image_asset_id,
    box->0 as x1,
    box->1 as y1,
    box->2 as x2,
    box->3 as y2,
    label,
    score
FROM detections
WHERE image_asset_id = '660e8400-e29b-41d4-a716-446655440000';

-- Eval의 score 상세 조회
SELECT 
    eval_id,
    render_id,
    score->'ocr_conf' as ocr_confidence,
    score->'text_ratio' as text_ratio,
    score->'clip_score' as clip_score,
    score->'gate_pass' as gate_pass
FROM evals
WHERE (score->>'gate_pass')::boolean = true;

-- ============================================
-- 5. 통계 쿼리
-- ============================================

-- 테넌트별 이미지 개수
SELECT 
    t.tenant_id,
    t.display_name,
    COUNT(ia.image_asset_id) as image_count
FROM tenants t
LEFT JOIN image_assets ia ON t.tenant_id = ia.tenant_id
GROUP BY t.tenant_id, t.display_name
ORDER BY image_count DESC;

-- 날짜별 이미지 생성 통계
SELECT 
    DATE(created_at) as date,
    COUNT(*) as image_count
FROM image_assets
GROUP BY DATE(created_at)
ORDER BY date DESC
LIMIT 30;

-- Detection 평균 점수
SELECT 
    label,
    COUNT(*) as count,
    AVG(score) as avg_score,
    MIN(score) as min_score,
    MAX(score) as max_score
FROM detections
GROUP BY label
ORDER BY avg_score DESC;

-- ============================================
-- 6. 파이프라인 성공률 조회
-- ============================================

-- 전체 파이프라인 완료율
SELECT 
    COUNT(DISTINCT ia.image_asset_id) as total_images,
    COUNT(DISTINCT d.detection_id) as with_detection,
    COUNT(DISTINCT pp.proposal_id) as with_proposal,
    COUNT(DISTINCT r.render_id) as with_render,
    COUNT(DISTINCT e.eval_id) as with_eval,
    COUNT(DISTINCT jr.judge_result_id) as with_judge
FROM image_assets ia
LEFT JOIN detections d ON ia.image_asset_id = d.image_asset_id
LEFT JOIN planner_proposals pp ON ia.image_asset_id = pp.image_asset_id
LEFT JOIN overlay_layouts ol ON pp.proposal_id = ol.proposal_id
LEFT JOIN renders r ON ol.overlay_id = r.overlay_id
LEFT JOIN evals e ON r.render_id = e.render_id
LEFT JOIN judge_results jr ON e.eval_id = jr.eval_id;

-- ============================================
-- 7. 최근 활동 조회
-- ============================================

-- 최근 생성된 이미지와 파이프라인 상태
SELECT 
    ia.image_asset_id,
    ia.image_url,
    ia.created_at,
    CASE 
        WHEN jr.judge_result_id IS NOT NULL THEN 'completed'
        WHEN e.eval_id IS NOT NULL THEN 'evaluated'
        WHEN r.render_id IS NOT NULL THEN 'rendered'
        WHEN ol.overlay_id IS NOT NULL THEN 'overlay_planned'
        WHEN pp.proposal_id IS NOT NULL THEN 'proposed'
        WHEN d.detection_id IS NOT NULL THEN 'detected'
        ELSE 'new'
    END as pipeline_status
FROM image_assets ia
LEFT JOIN detections d ON ia.image_asset_id = d.image_asset_id
LEFT JOIN planner_proposals pp ON ia.image_asset_id = pp.image_asset_id
LEFT JOIN overlay_layouts ol ON pp.proposal_id = ol.proposal_id
LEFT JOIN renders r ON ol.overlay_id = r.overlay_id
LEFT JOIN evals e ON r.render_id = e.render_id
LEFT JOIN judge_results jr ON e.eval_id = jr.eval_id
ORDER BY ia.created_at DESC
LIMIT 20;

-- ============================================
-- 8. 검색 쿼리
-- ============================================

-- 특정 텍스트가 포함된 Proposal 검색
SELECT 
    proposal_id,
    image_asset_id,
    prompt,
    created_at
FROM planner_proposals
WHERE prompt LIKE '%특가%' OR prompt LIKE '%출시%'
ORDER BY created_at DESC;

-- 특정 점수 이상의 Eval 조회
SELECT 
    e.eval_id,
    r.render_id,
    (e.score->>'ocr_conf')::float as ocr_conf,
    (e.score->>'clip_score')::float as clip_score
FROM evals e
JOIN renders r ON e.render_id = r.render_id
WHERE (e.score->>'ocr_conf')::float > 0.9
ORDER BY (e.score->>'clip_score')::float DESC;

-- ============================================
-- 9. 데이터 정리 쿼리
-- ============================================

-- 오래된 이미지 조회 (30일 이상)
SELECT 
    image_asset_id,
    image_url,
    created_at,
    NOW() - created_at as age
FROM image_assets
WHERE created_at < NOW() - INTERVAL '30 days'
ORDER BY created_at ASC;

-- 완료되지 않은 파이프라인 조회
SELECT 
    ia.image_asset_id,
    ia.image_url,
    CASE 
        WHEN d.detection_id IS NULL THEN 'missing_detection'
        WHEN pp.proposal_id IS NULL THEN 'missing_proposal'
        WHEN ol.overlay_id IS NULL THEN 'missing_overlay'
        WHEN r.render_id IS NULL THEN 'missing_render'
        WHEN e.eval_id IS NULL THEN 'missing_eval'
        WHEN jr.judge_result_id IS NULL THEN 'missing_judge'
    END as missing_step
FROM image_assets ia
LEFT JOIN detections d ON ia.image_asset_id = d.image_asset_id
LEFT JOIN planner_proposals pp ON ia.image_asset_id = pp.image_asset_id
LEFT JOIN overlay_layouts ol ON pp.proposal_id = ol.proposal_id
LEFT JOIN renders r ON ol.overlay_id = r.overlay_id
LEFT JOIN evals e ON r.render_id = e.render_id
LEFT JOIN judge_results jr ON e.eval_id = jr.eval_id
WHERE jr.judge_result_id IS NULL
ORDER BY ia.created_at DESC;




