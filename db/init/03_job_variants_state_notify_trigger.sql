-- Job Variants State Change Notification Trigger
-- PostgreSQL LISTEN/NOTIFY를 사용하여 jobs_variants 테이블의 상태 변화를 실시간으로 감지
-- 
-- created_at: 2025-11-28
-- author: LEEYH205
-- description: Trigger function and trigger for job variant state change notifications
-- version: 1.0.0
--
-- 옵션 C (하이브리드) 구현:
-- - jobs_variants 상태 변경 시 NOTIFY 발행
-- - 모든 variants 완료 시 jobs 테이블 자동 업데이트

-- ============================================
-- 1. jobs_variants 상태 변경 NOTIFY 트리거
-- ============================================

-- 트리거 함수: jobs_variants 테이블 변경 시 NOTIFY 발행
CREATE OR REPLACE FUNCTION notify_job_variant_state_change()
RETURNS TRIGGER AS $$
BEGIN
    -- current_step 또는 status가 변경된 경우에만 NOTIFY 발행
    IF (OLD.current_step IS DISTINCT FROM NEW.current_step 
        OR OLD.status IS DISTINCT FROM NEW.status) THEN
        
        PERFORM pg_notify(
            'job_variant_state_changed',
            json_build_object(
                'job_variants_id', NEW.job_variants_id::text,
                'job_id', NEW.job_id::text,
                'current_step', NEW.current_step,
                'status', NEW.status,
                'img_asset_id', NEW.img_asset_id::text,
                'tenant_id', (SELECT tenant_id FROM jobs WHERE job_id = NEW.job_id),
                'updated_at', NEW.updated_at
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 기존 트리거가 있으면 삭제
DROP TRIGGER IF EXISTS job_variant_state_change_trigger ON jobs_variants;

-- 트리거 생성
CREATE TRIGGER job_variant_state_change_trigger
    AFTER UPDATE ON jobs_variants
    FOR EACH ROW
    EXECUTE FUNCTION notify_job_variant_state_change();

-- 트리거 생성 확인
COMMENT ON TRIGGER job_variant_state_change_trigger ON jobs_variants IS 
    'jobs_variants 테이블의 current_step 또는 status 변경 시 job_variant_state_changed 채널로 NOTIFY 발행';

-- ============================================
-- 2. 모든 variants 완료 시 jobs 테이블 자동 업데이트 트리거
-- ============================================

-- 트리거 함수: 모든 variants 완료 시 jobs 테이블 업데이트
CREATE OR REPLACE FUNCTION check_all_variants_done()
RETURNS TRIGGER AS $$
DECLARE
    total_count INTEGER;
    done_count INTEGER;
    failed_count INTEGER;
    job_status TEXT;
    job_current_step TEXT;
BEGIN
    -- 해당 job_id의 모든 variants 개수 확인
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'done'),
        COUNT(*) FILTER (WHERE status = 'failed')
    INTO total_count, done_count, failed_count
    FROM jobs_variants
    WHERE job_id = NEW.job_id;
    
    -- 모든 variants가 완료되면 jobs 테이블 업데이트
    IF total_count > 0 AND done_count = total_count THEN
        -- 모든 variants가 done 상태
        job_status := 'done';
        job_current_step := 'iou_eval';  -- yh 파트의 마지막 단계
    ELSIF failed_count > 0 AND (done_count + failed_count) = total_count THEN
        -- 일부는 done, 일부는 failed (전체 완료)
        job_status := 'failed';
        job_current_step := NEW.current_step;  -- 현재 단계 유지
    ELSIF done_count > 0 OR failed_count > 0 THEN
        -- 일부만 완료 (진행 중)
        job_status := 'running';
        job_current_step := 'vlm_analyze';  -- yh 파트 시작 단계 유지
    ELSE
        -- 아직 시작하지 않음
        RETURN NEW;
    END IF;
    
    -- jobs 테이블 업데이트
    UPDATE jobs 
    SET status = job_status,
        current_step = job_current_step,
        updated_at = CURRENT_TIMESTAMP
    WHERE job_id = NEW.job_id
      AND (status IS DISTINCT FROM job_status 
           OR current_step IS DISTINCT FROM job_current_step);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 기존 트리거가 있으면 삭제
DROP TRIGGER IF EXISTS check_all_variants_done_trigger ON jobs_variants;

-- 트리거 생성 (status가 'done' 또는 'failed'로 변경될 때만 실행)
CREATE TRIGGER check_all_variants_done_trigger
    AFTER UPDATE ON jobs_variants
    FOR EACH ROW
    WHEN (NEW.status = 'done' OR NEW.status = 'failed')
    EXECUTE FUNCTION check_all_variants_done();

-- 트리거 생성 확인
COMMENT ON TRIGGER check_all_variants_done_trigger ON jobs_variants IS 
    'jobs_variants 테이블의 status가 done 또는 failed로 변경될 때, 모든 variants 완료 여부를 확인하고 jobs 테이블을 자동 업데이트';

