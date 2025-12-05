# MaxOps 운영 매뉴얼

## 1. 일상 운영

### 1.1 서비스 상태 확인
```bash
# 전체 서비스 상태
docker compose ps

# 헬스체크 상태
curl -s http://localhost:9000/health | jq

# 개별 서비스 상태
curl http://localhost:9000/health/openproject
curl http://localhost:9000/health/gitea
```

### 1.2 로그 모니터링
```bash
# 전체 로그 (실시간)
docker compose logs -f

# 특정 서비스 로그
docker compose logs -f openproject
docker compose logs -f gitea

# 최근 100줄만 표시
docker compose logs --tail=100 openproject

# 특정 시간 이후 로그
docker compose logs --since="2024-01-01T00:00:00" openproject
```

### 1.3 리소스 모니터링
```bash
# 컨테이너 리소스 사용량
docker stats

# 디스크 사용량
docker system df

# 볼륨 사용량
docker volume ls
du -sh /var/lib/docker/volumes/maxoperation_*
```

---

## 2. 백업 및 복구

### 2.1 자동 백업 설정
```bash
# Crontab 설정 (매일 새벽 2시)
crontab -e

# 추가할 내용
0 2 * * * cd /home/hklee/project/maxoperation && docker compose exec -T backup /backup.sh backup >> /var/log/maxops-backup.log 2>&1
```

### 2.2 수동 백업
```bash
# 전체 백업 실행
docker compose exec backup /backup.sh backup

# 백업 파일 확인
ls -la backup/daily/

# 백업 무결성 검증
docker compose exec backup /backup.sh verify /backup/daily/openproject_*.sql.gz
```

### 2.3 데이터 복구
```bash
# OpenProject 데이터베이스 복원
docker compose exec -T postgres psql -U maxops -d openproject < backup_file.sql

# 또는 gzip 압축 파일 복원
gunzip -c backup/daily/openproject_20240101_020000.sql.gz | \
  docker compose exec -T postgres psql -U maxops -d openproject

# Gitea 데이터베이스 복원
gunzip -c backup/daily/gitea_20240101_020000.sql.gz | \
  docker compose exec -T postgres psql -U maxops -d gitea
```

### 2.4 볼륨 백업
```bash
# OpenProject 첨부파일 백업
docker run --rm -v maxoperation_openproject-assets:/data -v $(pwd)/backup:/backup \
  alpine tar czf /backup/openproject-assets.tar.gz -C /data .

# Gitea 저장소 백업
docker run --rm -v maxoperation_gitea-data:/data -v $(pwd)/backup:/backup \
  alpine tar czf /backup/gitea-data.tar.gz -C /data .
```

---

## 3. 업데이트 절차

### 3.1 정기 업데이트
```bash
# 1. 현재 상태 확인
docker compose ps
docker images | grep -E "(openproject|gitea)"

# 2. 백업 수행
docker compose exec backup /backup.sh backup

# 3. 이미지 업데이트
docker compose pull

# 4. 서비스 재시작
docker compose up -d

# 5. 상태 확인
docker compose ps
docker compose logs --tail=50

# 6. 오래된 이미지 정리
docker image prune -f
```

### 3.2 긴급 롤백
```bash
# 1. 현재 이미지 태그 확인
docker images

# 2. 이전 버전으로 롤백
docker compose down
# docker-compose.yml에서 이미지 태그 수정
docker compose up -d

# 3. 데이터베이스 롤백 (필요시)
gunzip -c backup/daily/openproject_이전날짜.sql.gz | \
  docker compose exec -T postgres psql -U maxops -d openproject
```

---

## 4. 트러블슈팅

### 4.1 서비스 시작 실패

**OpenProject 시작 실패**
```bash
# 에러 로그 확인
docker compose logs openproject

# 일반적인 원인들:
# 1. 데이터베이스 연결 실패
docker compose exec postgres pg_isready -U maxops

# 2. 메모리 부족
free -h
docker stats --no-stream

# 3. 볼륨 권한 문제
docker compose exec openproject ls -la /var/openproject/
```

**Gitea 시작 실패**
```bash
# 에러 로그 확인
docker compose logs gitea

# 데이터베이스 연결 테스트
docker compose exec postgres psql -U maxops -d gitea -c "SELECT 1"

# 설정 파일 확인
docker compose exec gitea cat /etc/gitea/app.ini
```

### 4.2 성능 저하

**데이터베이스 최적화**
```bash
# PostgreSQL 분석 실행
docker compose exec postgres psql -U maxops -d openproject -c "VACUUM ANALYZE"
docker compose exec postgres psql -U maxops -d gitea -c "VACUUM ANALYZE"

# 슬로우 쿼리 확인
docker compose exec postgres psql -U maxops -c \
  "SELECT pid, age(clock_timestamp(), query_start), usename, query
   FROM pg_stat_activity WHERE state != 'idle' ORDER BY query_start"
```

**Redis 캐시 정리**
```bash
# Redis 메모리 사용량 확인
docker compose exec redis redis-cli INFO memory

# 캐시 초기화 (주의: 세션 데이터 손실)
docker compose exec redis redis-cli FLUSHALL
```

### 4.3 연결 문제

**네트워크 진단**
```bash
# 컨테이너 간 통신 테스트
docker compose exec openproject ping postgres
docker compose exec gitea ping postgres

# 포트 확인
docker compose exec nginx netstat -tlnp

# DNS 확인
docker compose exec openproject nslookup postgres
```

**방화벽 확인**
```bash
# 리눅스 방화벽 상태
sudo ufw status
sudo iptables -L -n

# 포트 열기 (필요시)
sudo ufw allow 9000:9022/tcp
```

---

## 5. 사용자 관리

### 5.1 OpenProject 사용자 관리
```
경로: Administration > Users

작업:
- 사용자 추가: New User
- 역할 변경: 사용자 선택 > Projects 탭
- 비밀번호 초기화: 사용자 선택 > Reset password
- 사용자 비활성화: Status > Lock
```

### 5.2 Gitea 사용자 관리
```
경로: Site Administration > User Accounts

작업:
- 사용자 추가: Create User Account
- 관리자 권한 부여: Edit > Is Administrator
- 비밀번호 초기화: Edit > Change Password
- 계정 비활성화: Edit > Prohibit Login
```

### 5.3 일괄 사용자 추가 (Gitea)
```bash
# Gitea CLI를 통한 사용자 생성
docker compose exec gitea gitea admin user create \
  --username newuser \
  --password securepassword \
  --email user@example.com
```

---

## 6. 보안 운영

### 6.1 보안 점검 항목
| 항목 | 주기 | 담당 |
|------|------|------|
| 비밀번호 정책 확인 | 월간 | 보안팀 |
| 접근 로그 분석 | 주간 | 운영팀 |
| 취약점 스캔 | 월간 | 보안팀 |
| SSL 인증서 만료 확인 | 월간 | 운영팀 |
| 백업 복구 테스트 | 분기 | 운영팀 |

### 6.2 보안 로그 확인
```bash
# Nginx 접근 로그
docker compose exec nginx cat /var/log/nginx/access.log | tail -100

# 로그인 실패 시도 확인
docker compose logs gitea | grep -i "failed"
docker compose logs openproject | grep -i "failed"

# 의심스러운 IP 확인
docker compose exec nginx cat /var/log/nginx/access.log | \
  awk '{print $1}' | sort | uniq -c | sort -rn | head -20
```

### 6.3 보안 업데이트
```bash
# 보안 패치 확인
docker compose pull

# 취약점 스캔
docker scan openproject/openproject:14
docker scan gitea/gitea:1.21
```

---

## 7. 장애 대응

### 7.1 장애 등급 정의
| 등급 | 설명 | 대응 시간 |
|------|------|-----------|
| P1 | 전체 서비스 중단 | 15분 이내 |
| P2 | 주요 기능 장애 | 1시간 이내 |
| P3 | 부분 기능 장애 | 4시간 이내 |
| P4 | 경미한 문제 | 24시간 이내 |

### 7.2 장애 대응 절차
```
1. 장애 인지 및 초기 분석
   - 증상 확인
   - 영향 범위 파악
   - 장애 등급 결정

2. 긴급 조치
   - 서비스 재시작 시도
   - 로그 수집
   - 임시 우회 방안 적용

3. 원인 분석
   - 상세 로그 분석
   - 변경 이력 검토
   - 근본 원인 파악

4. 복구 및 정상화
   - 복구 작업 수행
   - 정상 동작 확인
   - 모니터링 강화

5. 사후 조치
   - RCA (Root Cause Analysis) 문서 작성
   - 재발 방지 대책 수립
   - 프로세스 개선
```

### 7.3 긴급 연락망
```
# 장애 발생 시 연락 순서
1. 시스템 운영팀 (1차 대응)
2. 개발팀 (기술 지원)
3. 보안팀 (보안 관련)
4. 경영진 (P1 장애)
```

---

## 8. 모니터링 설정

### 8.1 헬스체크 모니터링
```bash
# 크론 작업으로 헬스체크 (5분마다)
*/5 * * * * curl -s http://localhost:9000/health || echo "서비스 장애" | mail -s "MaxOps Alert" admin@example.com
```

### 8.2 디스크 용량 모니터링
```bash
# 디스크 사용량 알림 스크립트
#!/bin/bash
THRESHOLD=80
USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')

if [ $USAGE -gt $THRESHOLD ]; then
    echo "디스크 사용량 경고: ${USAGE}%" | \
      mail -s "MaxOps 디스크 경고" admin@example.com
fi
```

### 8.3 외부 모니터링 연동
```yaml
# Prometheus 스크래핑 설정 예시
scrape_configs:
  - job_name: 'maxops-nginx'
    static_configs:
      - targets: ['localhost:9000']
    metrics_path: /metrics

  - job_name: 'maxops-postgres'
    static_configs:
      - targets: ['localhost:9003']
```

---

## 9. 참고 명령어 모음

### 빠른 참조
```bash
# 서비스 상태
docker compose ps

# 전체 재시작
docker compose restart

# 로그 확인
docker compose logs -f --tail=100

# 백업 실행
docker compose exec backup /backup.sh backup

# 시스템 정리
docker system prune -f

# 이미지 업데이트
docker compose pull && docker compose up -d
```
