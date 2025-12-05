-- ============================================
-- MaxOps PostgreSQL 초기화 스크립트
-- OpenProject와 Gitea용 데이터베이스 생성
-- ============================================

-- 한국어 로케일 설정을 위한 기본 설정
SET client_encoding = 'UTF8';

-- ============================================
-- 1. OpenProject 데이터베이스 (기본 생성됨)
-- ============================================
-- openproject 데이터베이스는 docker-compose에서 POSTGRES_DB로 자동 생성됨

-- ============================================
-- 2. Gitea 데이터베이스 생성
-- ============================================
CREATE DATABASE gitea
    WITH
    OWNER = maxops
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TEMPLATE = template0
    CONNECTION LIMIT = -1;

-- Gitea 데이터베이스 권한 부여
GRANT ALL PRIVILEGES ON DATABASE gitea TO maxops;

-- ============================================
-- 3. 공통 확장 모듈 설치
-- ============================================

-- OpenProject 데이터베이스에 확장 모듈 설치
\c openproject

-- UUID 생성 함수
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 전문 검색 (한국어 지원)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 암호화 함수
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Gitea 데이터베이스에도 동일하게 적용
\c gitea

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================
-- 4. 감사 로그 테이블 생성 (공통)
-- ============================================
\c openproject

-- 시스템 감사 로그 테이블
CREATE TABLE IF NOT EXISTS system_audit_logs (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    event_source VARCHAR(50) NOT NULL,
    user_id VARCHAR(100),
    user_name VARCHAR(255),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),
    resource_id VARCHAR(100),
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성 (검색 성능 향상)
CREATE INDEX idx_audit_logs_event_type ON system_audit_logs(event_type);
CREATE INDEX idx_audit_logs_user_id ON system_audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON system_audit_logs(created_at);
CREATE INDEX idx_audit_logs_resource ON system_audit_logs(resource_type, resource_id);

-- 감사 로그 삽입 함수
CREATE OR REPLACE FUNCTION log_audit_event(
    p_event_type VARCHAR(50),
    p_event_source VARCHAR(50),
    p_user_id VARCHAR(100),
    p_user_name VARCHAR(255),
    p_action VARCHAR(100),
    p_resource_type VARCHAR(100),
    p_resource_id VARCHAR(100),
    p_details JSONB DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_log_id INTEGER;
BEGIN
    INSERT INTO system_audit_logs (
        event_type, event_source, user_id, user_name,
        action, resource_type, resource_id, details,
        ip_address, user_agent
    ) VALUES (
        p_event_type, p_event_source, p_user_id, p_user_name,
        p_action, p_resource_type, p_resource_id, p_details,
        p_ip_address, p_user_agent
    ) RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. 초기화 완료 로그
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '====================================';
    RAISE NOTICE 'MaxOps 데이터베이스 초기화 완료';
    RAISE NOTICE '- OpenProject DB: openproject';
    RAISE NOTICE '- Gitea DB: gitea';
    RAISE NOTICE '- 시간: %', NOW();
    RAISE NOTICE '====================================';
END $$;
