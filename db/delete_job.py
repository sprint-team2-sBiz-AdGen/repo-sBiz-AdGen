#!/usr/bin/env python3
"""
Job ID를 인자로 받아 관련된 모든 데이터를 삭제하는 스크립트

Usage:
    python delete_job.py <job_id>
    python delete_job.py 63a19d53-6bfd-4ec4-9dc0-85e423ad7743
"""

import os
import sys
import argparse
import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, List, Tuple


# 환경 변수에서 DB 설정 가져오기
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "feedlyai")
DB_USER = os.getenv("DB_USER", "feedlyai")
DB_PASSWORD = os.getenv("DB_PASSWORD", "feedlyai_dev_password_74154")


def get_db_connection():
    """데이터베이스 연결 생성"""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )


def get_dict_cursor(conn):
    """RealDictCursor 생성"""
    return conn.cursor(cursor_factory=RealDictCursor)


def get_regular_cursor(conn):
    """일반 cursor 생성 (COUNT 쿼리용)"""
    return conn.cursor()


def check_job_exists(cursor, job_id: str) -> Dict:
    """Job이 존재하는지 확인하고 정보 반환"""
    cursor.execute("""
        SELECT job_id, tenant_id, store_id, status, current_step, created_at
        FROM jobs
        WHERE job_id = %s
    """, (job_id,))
    
    result = cursor.fetchone()
    return dict(result) if result else None


def count_related_data(conn, job_id: str) -> Dict[str, int]:
    """관련 데이터 개수 확인"""
    counts = {}
    cursor = get_regular_cursor(conn)
    
    try:
        tables = [
            'jobs',
            'job_inputs',
            'jobs_variants',
            'vlm_traces',
            'llm_traces',
            'txt_ad_copy_generations',
            'instagram_feeds',
            'evaluations',
            'yolo_runs',
            'detections',
            'gen_runs',
            'image_assets'
        ]
        
        for table in tables:
            if table == 'jobs':
                cursor.execute("SELECT COUNT(*) FROM jobs WHERE job_id = %s", (job_id,))
            else:
                cursor.execute(f"SELECT COUNT(*) FROM {table} WHERE job_id = %s", (job_id,))
            result = cursor.fetchone()
            counts[table] = result[0] if result else 0
        
        # overlay_layouts는 jobs_variants_id를 통해 확인
        cursor.execute("""
            SELECT COUNT(*) 
            FROM overlay_layouts
            WHERE job_variants_id IN (
                SELECT job_variants_id FROM jobs_variants 
                WHERE job_id = %s
            )
        """, (job_id,))
        result = cursor.fetchone()
        counts['overlay_layouts'] = result[0] if result else 0
    finally:
        cursor.close()
    
    return counts


def delete_job_data(cursor, conn, job_id: str) -> Dict[str, int]:
    """Job과 관련된 모든 데이터 삭제"""
    deleted_counts = {}
    
    # Foreign Key 제약조건을 고려하여 자식 테이블부터 삭제
    delete_queries = [
        # 1. txt_ad_copy_generations
        ("txt_ad_copy_generations", "DELETE FROM txt_ad_copy_generations WHERE job_id = %s"),
        
        # 2. instagram_feeds
        ("instagram_feeds", "DELETE FROM instagram_feeds WHERE job_id = %s"),
        
        # 3. evaluations
        ("evaluations", "DELETE FROM evaluations WHERE job_id = %s"),
        
        # 4. vlm_traces
        ("vlm_traces", "DELETE FROM vlm_traces WHERE job_id = %s"),
        
        # 5. llm_traces
        ("llm_traces", "DELETE FROM llm_traces WHERE job_id = %s"),
        
        # 6. overlay_layouts (jobs_variants_id를 통해)
        ("overlay_layouts", """
            DELETE FROM overlay_layouts
            WHERE job_variants_id IN (
                SELECT job_variants_id FROM jobs_variants 
                WHERE job_id = %s
            )
        """),
        
        # 7. jobs_variants
        ("jobs_variants", "DELETE FROM jobs_variants WHERE job_id = %s"),
        
        # 8. yolo_runs
        ("yolo_runs", "DELETE FROM yolo_runs WHERE job_id = %s"),
        
        # 9. detections
        ("detections", "DELETE FROM detections WHERE job_id = %s"),
        
        # 10. gen_variants (gen_runs의 자식 테이블이므로 먼저 삭제)
        ("gen_variants", """
            DELETE FROM gen_variants
            WHERE run_id IN (
                SELECT run_id FROM gen_runs WHERE job_id = %s
            )
        """),
        
        # 11. gen_runs
        ("gen_runs", "DELETE FROM gen_runs WHERE job_id = %s"),
        
        # 11. job_inputs
        ("job_inputs", "DELETE FROM job_inputs WHERE job_id = %s"),
        
        # 12. image_assets (job_id로 연결된 것만)
        ("image_assets", "DELETE FROM image_assets WHERE job_id = %s AND job_id IS NOT NULL"),
        
        # 13. jobs (마지막으로 삭제)
        ("jobs", "DELETE FROM jobs WHERE job_id = %s"),
    ]
    
    for table_name, query in delete_queries:
        cursor.execute(query, (job_id,))
        deleted_counts[table_name] = cursor.rowcount
        print(f"  ✓ {table_name}: {cursor.rowcount}개 삭제")
    
    conn.commit()
    return deleted_counts


def main():
    parser = argparse.ArgumentParser(
        description='Job ID를 인자로 받아 관련된 모든 데이터를 삭제합니다.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예제:
  python delete_job.py 63a19d53-6bfd-4ec4-9dc0-85e423ad7743
        """
    )
    parser.add_argument(
        'job_id',
        type=str,
        help='삭제할 Job ID (UUID)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='실제 삭제하지 않고 관련 데이터만 확인'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='확인 없이 바로 삭제'
    )
    
    args = parser.parse_args()
    job_id = args.job_id
    
    # UUID 형식 간단 검증
    if len(job_id) != 36 or job_id.count('-') != 4:
        print(f"❌ 오류: 올바른 UUID 형식이 아닙니다: {job_id}")
        sys.exit(1)
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Job 존재 확인
        print(f"🔍 Job ID 확인 중: {job_id}")
        job_info = check_job_exists(cursor, job_id)
        
        if not job_info:
            print(f"❌ Job ID를 찾을 수 없습니다: {job_id}")
            cursor.close()
            conn.close()
            sys.exit(1)
        
        print(f"✅ Job 정보:")
        print(f"   - Tenant ID: {job_info['tenant_id']}")
        print(f"   - Store ID: {job_info['store_id']}")
        print(f"   - Status: {job_info['status']}")
        print(f"   - Current Step: {job_info['current_step']}")
        print(f"   - Created At: {job_info['created_at']}")
        print()
        
        # 관련 데이터 개수 확인
        print("📊 관련 데이터 확인 중...")
        counts = count_related_data(conn, job_id)
        
        total_count = sum(counts.values())
        if total_count == 0:
            print("⚠️  관련 데이터가 없습니다. Job만 삭제됩니다.")
        else:
            print("📋 관련 데이터:")
            for table, count in counts.items():
                if count > 0:
                    print(f"   - {table}: {count}개")
        print()
        
        if args.dry_run:
            print("🔍 Dry-run 모드: 실제 삭제는 수행하지 않습니다.")
            cursor.close()
            conn.close()
            return
        
        # 삭제 확인
        if not args.force:
            print("⚠️  경고: 이 작업은 되돌릴 수 없습니다!")
            response = input(f"정말로 Job '{job_id}'와 관련된 모든 데이터를 삭제하시겠습니까? (yes/no): ")
            if response.lower() not in ['yes', 'y']:
                print("❌ 삭제가 취소되었습니다.")
                cursor.close()
                conn.close()
                return
        
        # 삭제 실행
        print(f"\n🗑️  삭제 시작...")
        deleted_counts = delete_job_data(cursor, conn, job_id)
        
        # 최종 확인
        print(f"\n🔍 삭제 결과 확인 중...")
        final_counts = count_related_data(conn, job_id)
        
        remaining = sum(final_counts.values())
        if remaining == 0:
            print(f"✅ 성공: Job '{job_id}'와 관련된 모든 데이터가 삭제되었습니다.")
        else:
            print(f"⚠️  경고: 일부 데이터가 남아있습니다.")
            for table, count in final_counts.items():
                if count > 0:
                    print(f"   - {table}: {count}개 남음")
        
        cursor.close()
        conn.close()
        
    except psycopg2.Error as e:
        print(f"❌ 데이터베이스 오류: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n❌ 사용자에 의해 중단되었습니다.")
        if conn:
            conn.rollback()
            conn.close()
        sys.exit(1)
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        if conn:
            conn.rollback()
            conn.close()
        sys.exit(1)


if __name__ == '__main__':
    main()

