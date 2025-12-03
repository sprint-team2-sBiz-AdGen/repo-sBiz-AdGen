-- Job Variants State Change Notification Trigger
-- PostgreSQL LISTEN/NOTIFY를 사용하여 jobs_variants 테이블의 상태 변화를 실시간으로 감지
-- 
-- created_at: 2025-11-28
-- updated_at: 2025-11-29
-- author: LEEYH205
-- description: Trigger function and trigger for job variant state change notifications
-- version: 1.3.0
-- changes: iou_eval 단계 처리 시 디버깅 로깅 추가
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
DECLARE
    should_notify BOOLEAN := FALSE;
    notify_reason TEXT;
BEGIN
    -- current_step, status, 또는 updated_at이 변경된 경우 NOTIFY 발행
    -- updated_at 변경도 감지하여 INSERT 후 UPDATE 시 트리거 발동
    IF OLD.current_step IS DISTINCT FROM NEW.current_step THEN
        should_notify := TRUE;
        notify_reason := 'current_step changed';
    ELSIF OLD.status IS DISTINCT FROM NEW.status THEN
        should_notify := TRUE;
        notify_reason := 'status changed';
    ELSIF OLD.updated_at IS DISTINCT FROM NEW.updated_at THEN
        should_notify := TRUE;
        notify_reason := 'updated_at changed';
    END IF;
    
    -- 디버깅 로깅
    RAISE NOTICE '[NOTIFY_TRIGGER] variant_id=%, job_id=%, reason=%, old_updated_at=%, new_updated_at=%', 
        NEW.job_variants_id, NEW.job_id, notify_reason, OLD.updated_at, NEW.updated_at;
    
    IF should_notify THEN
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
        RAISE NOTICE '[NOTIFY_TRIGGER] ✅ NOTIFY 발행 완료: variant_id=%', NEW.job_variants_id;
    ELSE
        RAISE NOTICE '[NOTIFY_TRIGGER] ⚠️ NOTIFY 발행 안 함: 변경사항 없음';
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
    'jobs_variants 테이블의 current_step, status, 또는 updated_at 변경 시 job_variant_state_changed 채널로 NOTIFY 발행. updated_at 변경도 감지하여 INSERT 후 UPDATE 시 트리거 발동';

-- ============================================
-- 2. 모든 variants 완료 시 jobs 테이블 자동 업데이트 트리거
-- ============================================

-- 트리거 함수: 모든 variants 완료 시 jobs 테이블 업데이트
-- 매 단계마다 모든 variants가 같은 단계에서 done이면 jobs 테이블도 해당 단계로 업데이트
CREATE OR REPLACE FUNCTION check_all_variants_done()
RETURNS TRIGGER AS $$
DECLARE
    total_count INTEGER;
    done_count INTEGER;
    failed_count INTEGER;
    running_count INTEGER;
    queued_count INTEGER;
    current_step_done_count INTEGER;  -- 현재 단계에서 done인 variants 개수
    current_step_failed_count INTEGER;  -- 현재 단계에서 failed인 variants 개수
    job_status TEXT;
    job_current_step TEXT;
    all_same_step_done BOOLEAN;  -- 모든 variants가 같은 단계에서 done인지
    iou_eval_done_count INTEGER;  -- iou_eval에서 done인 variant 개수
BEGIN
    -- 해당 job_id의 모든 variants 개수 및 상태 확인
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'done'),
        COUNT(*) FILTER (WHERE status = 'failed'),
        COUNT(*) FILTER (WHERE status = 'running'),
        COUNT(*) FILTER (WHERE status = 'queued'),
        COUNT(*) FILTER (WHERE status = 'done' AND current_step = NEW.current_step),  -- 현재 단계에서 done
        COUNT(*) FILTER (WHERE status = 'failed' AND current_step = NEW.current_step)  -- 현재 단계에서 failed
    INTO total_count, done_count, failed_count, running_count, queued_count,
         current_step_done_count, current_step_failed_count
    FROM jobs_variants
    WHERE job_id = NEW.job_id;
    
    -- img_gen 단계는 제외 (파이프라인 시작 전 단계)
    IF NEW.current_step = 'img_gen' THEN
        RETURN NEW;
    END IF;
    
    -- 모든 variants가 같은 단계에서 done인지 확인
    all_same_step_done := (current_step_done_count = total_count);
    
    -- iou_eval 단계 특별 처리: 모든 variants가 iou_eval, done일 때만 job을 done으로 업데이트
    -- (failed나 진행 중인 variant가 있으면 안 됨 - 파이프라인 뒷 파트에서 모든 variants 활용)
    IF NEW.current_step = 'iou_eval' AND NEW.status = 'done' THEN
        -- iou_eval에서 done인 variant 개수 확인 (NEW 레코드 포함)
        SELECT COUNT(*) INTO iou_eval_done_count
        FROM jobs_variants
        WHERE job_id = NEW.job_id
          AND current_step = 'iou_eval'
          AND status = 'done';
        
        -- 디버깅 로깅 (트리거 실행 여부 및 조건 확인)
        RAISE NOTICE '[TRIGGER] iou_eval done 체크: job_id=%, variant_id=%, iou_done=%, total=%, running=%, queued=%, failed=%', 
            NEW.job_id, NEW.job_variants_id, iou_eval_done_count, total_count, running_count, queued_count, failed_count;
        
        -- 모든 variants가 iou_eval, done인 경우에만 job을 done으로 업데이트
        -- (failed나 running/queued variant가 없어야 함)
        -- 중요: NEW 레코드가 이미 업데이트된 상태이므로, iou_eval_done_count는 NEW를 포함하여 계산됨
        IF iou_eval_done_count = total_count AND running_count = 0 AND queued_count = 0 AND failed_count = 0 THEN
            job_status := 'done';
            job_current_step := 'iou_eval';
            RAISE NOTICE '[TRIGGER] ✅ Job을 done으로 업데이트: job_id=%', NEW.job_id;
        ELSE
            job_status := 'running';
            job_current_step := 'iou_eval';
            RAISE NOTICE '[TRIGGER] ❌ Job을 done으로 업데이트하지 않음: job_id=%, 조건 불만족 (iou_done=% != total=% OR running=% OR queued=% OR failed=%)', 
                NEW.job_id, iou_eval_done_count, total_count, running_count, queued_count, failed_count;
        END IF;
    -- 모든 variants가 같은 단계에서 done인 경우 (iou_eval 제외, 위에서 처리)
    ELSIF all_same_step_done AND NEW.current_step != 'iou_eval' THEN
        job_status := 'done';
        job_current_step := NEW.current_step;  -- 현재 단계로 업데이트
    -- 일부는 done, 일부는 failed (전체 완료)
    ELSIF failed_count > 0 AND (done_count + failed_count) = total_count THEN
        job_status := 'failed';
        job_current_step := NEW.current_step;  -- 현재 단계 유지
    -- 진행 중인 variants가 있는 경우
    ELSIF running_count > 0 OR queued_count > 0 THEN
        job_status := 'running';
        -- 현재 단계에서 done인 variants가 있으면 해당 단계로 업데이트
        IF current_step_done_count > 0 THEN
            job_current_step := NEW.current_step;
        ELSE
            -- 아직 현재 단계에서 done인 variant가 없으면 이전 단계 유지
            -- (jobs 테이블의 current_step을 변경하지 않음)
            SELECT current_step INTO job_current_step
            FROM jobs
            WHERE job_id = NEW.job_id;
        END IF;
    -- 일부만 완료 (진행 중)
    ELSIF done_count > 0 OR failed_count > 0 THEN
        job_status := 'running';
        -- 현재 단계에서 done인 variants가 있으면 해당 단계로 업데이트
        IF current_step_done_count > 0 THEN
            job_current_step := NEW.current_step;
        ELSE
            -- 아직 현재 단계에서 done인 variant가 없으면 이전 단계 유지
            SELECT current_step INTO job_current_step
            FROM jobs
            WHERE job_id = NEW.job_id;
        END IF;
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
    'jobs_variants 테이블의 status가 done 또는 failed로 변경될 때, 모든 variants 완료 여부를 확인하고 jobs 테이블을 자동 업데이트. 매 단계마다 모든 variants가 같은 단계에서 done이면 jobs.current_step도 해당 단계로 업데이트. img_gen 단계는 제외';

