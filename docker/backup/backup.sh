#!/bin/bash
# ============================================
# MaxOps 자동 백업 스크립트
# PostgreSQL 데이터베이스 및 파일 백업
# ============================================

set -e

# ------------------------------------------
# 설정 변수
# ------------------------------------------
BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# PostgreSQL 접속 정보
PG_HOST="postgres"
PG_PORT="5432"
PG_USER="${POSTGRES_USER:-maxops}"
DATABASES=("openproject" "gitea")

# 로그 파일
LOG_FILE="${BACKUP_DIR}/backup.log"

# ------------------------------------------
# 함수 정의
# ------------------------------------------

# 로그 출력 함수
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# 백업 디렉토리 생성
create_backup_dirs() {
    log "INFO" "백업 디렉토리 생성 중..."
    mkdir -p "${BACKUP_DIR}/daily"
    mkdir -p "${BACKUP_DIR}/weekly"
    mkdir -p "${BACKUP_DIR}/monthly"
    mkdir -p "${BACKUP_DIR}/logs"
}

# PostgreSQL 데이터베이스 백업
backup_database() {
    local db_name=$1
    local backup_file="${BACKUP_DIR}/daily/${db_name}_${DATE}.sql.gz"

    log "INFO" "데이터베이스 백업 시작: ${db_name}"

    # pg_dump 실행 및 압축
    if pg_dump -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" \
        --format=custom --verbose --file="${backup_file%.gz}" "${db_name}" 2>> "${LOG_FILE}"; then

        # 압축
        gzip -f "${backup_file%.gz}"

        # 백업 파일 크기 확인
        local size=$(du -h "${backup_file}" | cut -f1)
        log "INFO" "데이터베이스 백업 완료: ${db_name} (${size})"

        # 체크섬 생성
        sha256sum "${backup_file}" > "${backup_file}.sha256"

        return 0
    else
        log "ERROR" "데이터베이스 백업 실패: ${db_name}"
        return 1
    fi
}

# 전체 데이터베이스 백업
backup_all_databases() {
    local failed=0

    for db in "${DATABASES[@]}"; do
        if ! backup_database "${db}"; then
            ((failed++))
        fi
    done

    return ${failed}
}

# 오래된 백업 정리
cleanup_old_backups() {
    log "INFO" "오래된 백업 파일 정리 중... (${RETENTION_DAYS}일 이전)"

    # 일일 백업 정리
    find "${BACKUP_DIR}/daily" -type f -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true

    # 주간 백업 정리 (90일)
    find "${BACKUP_DIR}/weekly" -type f -mtime +90 -delete 2>/dev/null || true

    # 월간 백업 정리 (365일)
    find "${BACKUP_DIR}/monthly" -type f -mtime +365 -delete 2>/dev/null || true

    log "INFO" "백업 정리 완료"
}

# 주간/월간 백업 생성
create_periodic_backups() {
    local day_of_week=$(date +%u)
    local day_of_month=$(date +%d)

    # 일요일이면 주간 백업 복사
    if [ "${day_of_week}" -eq 7 ]; then
        log "INFO" "주간 백업 생성 중..."
        for db in "${DATABASES[@]}"; do
            local source="${BACKUP_DIR}/daily/${db}_${DATE}.sql.gz"
            local dest="${BACKUP_DIR}/weekly/${db}_week_$(date +%Y%W).sql.gz"
            if [ -f "${source}" ]; then
                cp "${source}" "${dest}"
                cp "${source}.sha256" "${dest}.sha256"
            fi
        done
    fi

    # 매월 1일이면 월간 백업 복사
    if [ "${day_of_month}" -eq "01" ]; then
        log "INFO" "월간 백업 생성 중..."
        for db in "${DATABASES[@]}"; do
            local source="${BACKUP_DIR}/daily/${db}_${DATE}.sql.gz"
            local dest="${BACKUP_DIR}/monthly/${db}_month_$(date +%Y%m).sql.gz"
            if [ -f "${source}" ]; then
                cp "${source}" "${dest}"
                cp "${source}.sha256" "${dest}.sha256"
            fi
        done
    fi
}

# 백업 상태 보고서 생성
generate_report() {
    local report_file="${BACKUP_DIR}/logs/report_${DATE}.txt"

    {
        echo "============================================"
        echo "MaxOps 백업 보고서"
        echo "생성 시간: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "============================================"
        echo ""
        echo "## 백업 현황"
        echo ""

        echo "### 일일 백업"
        ls -lh "${BACKUP_DIR}/daily"/*.sql.gz 2>/dev/null | tail -10 || echo "백업 없음"
        echo ""

        echo "### 주간 백업"
        ls -lh "${BACKUP_DIR}/weekly"/*.sql.gz 2>/dev/null | tail -5 || echo "백업 없음"
        echo ""

        echo "### 월간 백업"
        ls -lh "${BACKUP_DIR}/monthly"/*.sql.gz 2>/dev/null | tail -5 || echo "백업 없음"
        echo ""

        echo "## 디스크 사용량"
        du -sh "${BACKUP_DIR}"/* 2>/dev/null || echo "정보 없음"
        echo ""

        echo "============================================"
    } > "${report_file}"

    log "INFO" "백업 보고서 생성: ${report_file}"
}

# 백업 무결성 검증
verify_backup() {
    local backup_file=$1
    local checksum_file="${backup_file}.sha256"

    if [ -f "${checksum_file}" ]; then
        if sha256sum -c "${checksum_file}" >/dev/null 2>&1; then
            log "INFO" "백업 무결성 검증 성공: ${backup_file}"
            return 0
        else
            log "ERROR" "백업 무결성 검증 실패: ${backup_file}"
            return 1
        fi
    else
        log "WARN" "체크섬 파일 없음: ${checksum_file}"
        return 1
    fi
}

# ------------------------------------------
# 메인 실행
# ------------------------------------------
main() {
    log "INFO" "=========================================="
    log "INFO" "MaxOps 백업 시작"
    log "INFO" "=========================================="

    # 백업 디렉토리 생성
    create_backup_dirs

    # 데이터베이스 백업
    if backup_all_databases; then
        log "INFO" "모든 데이터베이스 백업 성공"
    else
        log "WARN" "일부 데이터베이스 백업 실패"
    fi

    # 주기적 백업 생성
    create_periodic_backups

    # 오래된 백업 정리
    cleanup_old_backups

    # 보고서 생성
    generate_report

    log "INFO" "=========================================="
    log "INFO" "MaxOps 백업 완료"
    log "INFO" "=========================================="
}

# ------------------------------------------
# 복원 명령어 안내
# ------------------------------------------
show_restore_help() {
    echo "============================================"
    echo "백업 복원 방법"
    echo "============================================"
    echo ""
    echo "1. 데이터베이스 복원:"
    echo "   gunzip -c backup_file.sql.gz | psql -h postgres -U maxops -d database_name"
    echo ""
    echo "2. pg_restore 사용 (custom format):"
    echo "   pg_restore -h postgres -U maxops -d database_name backup_file.sql"
    echo ""
    echo "3. 특정 테이블만 복원:"
    echo "   pg_restore -h postgres -U maxops -d database_name -t table_name backup_file.sql"
    echo ""
}

# ------------------------------------------
# 명령행 인자 처리
# ------------------------------------------
case "${1:-}" in
    backup)
        main
        ;;
    restore-help)
        show_restore_help
        ;;
    verify)
        if [ -n "${2:-}" ]; then
            verify_backup "$2"
        else
            echo "사용법: $0 verify <backup_file>"
            exit 1
        fi
        ;;
    *)
        echo "사용법: $0 {backup|restore-help|verify <file>}"
        echo ""
        echo "  backup       - 전체 백업 실행"
        echo "  restore-help - 복원 방법 안내"
        echo "  verify       - 백업 무결성 검증"
        exit 1
        ;;
esac
