-- Job State Change Notification Trigger
-- PostgreSQL LISTEN/NOTIFY를 사용하여 jobs 테이블의 상태 변화를 실시간으로 감지
-- 
-- created_at: 2025-11-28
-- author: LEEYH205
-- description: Trigger function and trigger for job state change notifications
-- version: 1.0.0

-- 트리거 함수: jobs 테이블 변경 시 NOTIFY 발행
CREATE OR REPLACE FUNCTION notify_job_state_change()
RETURNS TRIGGER AS $$
BEGIN
    -- current_step 또는 status가 변경된 경우에만 NOTIFY 발행
    IF (OLD.current_step IS DISTINCT FROM NEW.current_step 
        OR OLD.status IS DISTINCT FROM NEW.status) THEN
        
        PERFORM pg_notify(
            'job_state_changed',
            json_build_object(
                'job_id', NEW.job_id::text,
                'current_step', NEW.current_step,
                'status', NEW.status,
                'tenant_id', NEW.tenant_id,
                'updated_at', NEW.updated_at
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 기존 트리거가 있으면 삭제
DROP TRIGGER IF EXISTS job_state_change_trigger ON jobs;

-- 트리거 생성
CREATE TRIGGER job_state_change_trigger
    AFTER UPDATE ON jobs
    FOR EACH ROW
    EXECUTE FUNCTION notify_job_state_change();

-- 트리거 생성 확인
COMMENT ON TRIGGER job_state_change_trigger ON jobs IS 
    'jobs 테이블의 current_step 또는 status 변경 시 job_state_changed 채널로 NOTIFY 발행';

