# OpenProject + Gitea 통합 시스템 구현 계획서

## 1. 구현 개요

### 1.1 목표
Docker 기반으로 OpenProject와 Gitea를 통합 구축하여 프로젝트 관리 시스템 구현

### 1.2 기술 스택
| 구분 | 기술 | 버전 |
|------|------|------|
| 컨테이너 | Docker, Docker Compose | 24.x, 2.x |
| 프로젝트 관리 | OpenProject | 14.x |
| Git 저장소 | Gitea | 1.21.x |
| 데이터베이스 | PostgreSQL | 15.x |
| 캐시 | Redis | 7.x |
| 웹 서버 | Nginx | Alpine |
| CI/CD | Gitea Actions | 최신 |

### 1.3 포트 구성
| 서비스 | 내부 포트 | 외부 포트 | 용도 |
|--------|-----------|-----------|------|
| Nginx | 80/443 | 9000/9443 | 리버스 프록시 |
| OpenProject | 80 | 9001 | 프로젝트 관리 |
| Gitea | 3000 | 9002 | Git 저장소 |
| PostgreSQL | 5432 | 9003 | 데이터베이스 |
| Redis | 6379 | 9004 | 캐시 |
| Gitea SSH | 22 | 9022 | Git SSH |

---

## 2. 구현 단계

### Phase 1: 인프라 구축 (기초 설정)

#### Step 1.1: 환경 준비
```bash
# 작업 순서
1. Docker 및 Docker Compose 설치 확인
2. 프로젝트 디렉토리 구조 생성
3. 환경 변수 파일 설정
4. 네트워크 및 볼륨 생성
```

**체크리스트**
- [ ] Docker 버전 확인 (20.x 이상)
- [ ] Docker Compose 버전 확인 (2.x 이상)
- [ ] 시스템 메모리 확인 (최소 4GB 권장)
- [ ] 디스크 공간 확인 (최소 20GB)

#### Step 1.2: 기본 서비스 실행
```bash
# PostgreSQL, Redis 먼저 실행
docker compose up -d postgres redis

# 데이터베이스 초기화 확인
docker compose logs postgres

# 헬스체크 확인
docker compose ps
```

**검증 항목**
- [ ] PostgreSQL 연결 테스트
- [ ] Redis 연결 테스트
- [ ] 데이터베이스 생성 확인 (openproject, gitea)

---

### Phase 2: 핵심 서비스 구축

#### Step 2.1: OpenProject 설치 및 설정
```bash
# OpenProject 컨테이너 실행
docker compose up -d openproject

# 초기화 완료 대기 (약 2-3분 소요)
docker compose logs -f openproject

# 상태 확인
curl http://localhost:9001/health_checks/default
```

**초기 설정 작업**
1. 관리자 계정 생성
2. 한국어 언어 팩 활성화
3. 프로젝트 템플릿 설정
4. 사용자 역할 및 권한 정의
5. 작업 유형 (Epic, Feature, Task, Bug) 설정
6. 워크플로우 상태 정의

**OpenProject 설정 상세**
```yaml
# 작업 유형 설정
Epic:
  색상: #7B68EE
  설명: 대규모 기능 단위

Feature:
  색상: #4169E1
  설명: 기능 개발

Task:
  색상: #32CD32
  설명: 일반 작업

Bug:
  색상: #FF4500
  설명: 버그 수정

Improvement:
  색상: #FFD700
  설명: 개선 사항
```

#### Step 2.2: Gitea 설치 및 설정
```bash
# Gitea 컨테이너 실행
docker compose up -d gitea

# 초기화 완료 확인
docker compose logs -f gitea

# 상태 확인
curl http://localhost:9002/api/healthz
```

**초기 설정 작업**
1. 관리자 계정 생성
2. 조직(Organization) 생성
3. 기본 저장소 템플릿 설정
4. Webhook 설정 (OpenProject 연동용)
5. Actions Runner 등록

**Gitea Actions 활성화**
```bash
# Runner 등록 토큰 발급 (관리자 페이지에서)
# Site Administration > Actions > Runners

# Runner 컨테이너 실행
docker compose up -d gitea-runner

# Runner 등록 확인
docker compose logs gitea-runner
```

---

### Phase 3: 서비스 연동

#### Step 3.1: OpenProject-Gitea 연동

**Webhook 설정**
```bash
# Gitea에서 Webhook 생성
# Repository > Settings > Webhooks > Add Webhook

Payload URL: http://openproject:80/webhooks/github
Content Type: application/json
Events: Push, Pull Request, Issues
```

**커밋 연동 규칙**
```
# 커밋 메시지에 OpenProject Task 번호 포함
git commit -m "OP#123 로그인 기능 구현"

# 자동으로 OpenProject Task에 커밋 정보 연결
```

#### Step 3.2: SSO 통합 (선택사항)
```yaml
# LDAP 설정 예시
OpenProject:
  - Administration > Authentication > LDAP

Gitea:
  - Site Administration > Authentication Sources > Add LDAP
```

---

### Phase 4: 리버스 프록시 설정

#### Step 4.1: Nginx 설정 및 실행
```bash
# Nginx 컨테이너 실행
docker compose up -d nginx

# 설정 검증
docker compose exec nginx nginx -t

# 접속 테스트
curl http://localhost:9000/health
```

**SSL 인증서 설정 (선택사항)**
```bash
# Let's Encrypt 사용 시
# certbot을 이용한 인증서 발급

# 자체 서명 인증서 생성
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout docker/nginx/ssl/server.key \
  -out docker/nginx/ssl/server.crt
```

---

### Phase 5: CI/CD 파이프라인 구축

#### Step 5.1: 기본 워크플로우 템플릿

**빌드 및 테스트 워크플로우**
```yaml
# .gitea/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Dependencies
        run: npm ci

      - name: Run Tests
        run: npm test

      - name: Build
        run: npm run build
```

**배포 워크플로우**
```yaml
# .gitea/workflows/deploy.yml
name: Deploy Pipeline

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Staging
        run: |
          # 스테이징 배포 스크립트
          ./scripts/deploy-staging.sh

  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-staging
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Production
        run: |
          # 운영 배포 스크립트
          ./scripts/deploy-production.sh
```

---

### Phase 6: 모니터링 및 백업 설정

#### Step 6.1: 백업 설정
```bash
# 백업 스크립트 실행 권한 부여
chmod +x docker/backup/backup.sh

# 수동 백업 실행
docker compose exec backup /backup.sh backup

# Cron 설정 (매일 새벽 2시)
# crontab -e
0 2 * * * docker compose -f /path/to/docker-compose.yml exec -T backup /backup.sh backup
```

#### Step 6.2: 로그 모니터링
```bash
# 전체 로그 확인
docker compose logs -f

# 특정 서비스 로그
docker compose logs -f openproject gitea

# 로그 파일 위치
/var/lib/docker/volumes/maxoperation_*
```

---

## 3. 실행 명령어 정리

### 3.1 전체 시스템 시작
```bash
# 환경 변수 파일 복사 및 설정
cp .env.example .env
vi .env  # 필요한 값 수정

# 전체 서비스 시작
docker compose up -d

# 상태 확인
docker compose ps

# 로그 확인
docker compose logs -f
```

### 3.2 개별 서비스 관리
```bash
# 특정 서비스 재시작
docker compose restart openproject

# 서비스 중지
docker compose stop gitea

# 서비스 로그
docker compose logs -f --tail=100 openproject
```

### 3.3 시스템 종료 및 정리
```bash
# 전체 서비스 중지
docker compose down

# 볼륨 포함 완전 삭제 (주의: 데이터 손실)
docker compose down -v

# 이미지 포함 삭제
docker compose down --rmi all
```

---

## 4. 문제 해결 가이드

### 4.1 일반적인 문제

**OpenProject 시작 실패**
```bash
# 원인: 데이터베이스 연결 실패
# 해결:
docker compose logs postgres
docker compose restart openproject
```

**Gitea Actions Runner 연결 실패**
```bash
# 원인: 토큰 미설정 또는 만료
# 해결:
1. Gitea 관리자 페이지에서 새 토큰 발급
2. .env 파일의 GITEA_RUNNER_TOKEN 업데이트
3. docker compose restart gitea-runner
```

**메모리 부족**
```bash
# 원인: 시스템 메모리 부족
# 해결:
# OpenProject 워커 수 조정
OPENPROJECT_WEB_WORKERS: 1
```

### 4.2 데이터 복구
```bash
# 데이터베이스 복원
gunzip -c backup_file.sql.gz | \
  docker compose exec -T postgres psql -U maxops -d openproject

# 특정 시점 복원
docker compose exec postgres pg_restore \
  -h localhost -U maxops -d openproject backup_file.sql
```

---

## 5. 보안 체크리스트

### 5.1 필수 보안 설정
- [ ] 기본 비밀번호 변경
- [ ] HTTPS 활성화
- [ ] 방화벽 설정 (9000-9022 포트만 허용)
- [ ] 정기 백업 설정
- [ ] 로그 모니터링 설정

### 5.2 권장 보안 설정
- [ ] 2단계 인증 (2FA) 활성화
- [ ] IP 화이트리스트 설정
- [ ] 감사 로그 활성화
- [ ] VPN 연동 (외부 접근 시)
- [ ] 보안 스캔 정기 실행

---

## 6. 유지보수 계획

### 6.1 정기 작업
| 주기 | 작업 | 담당 |
|------|------|------|
| 일간 | 백업 확인, 로그 모니터링 | 운영팀 |
| 주간 | 디스크 사용량 확인, 보안 업데이트 | 운영팀 |
| 월간 | 전체 시스템 점검, 성능 분석 | 운영팀 |
| 분기 | 재해 복구 테스트, 보안 감사 | 보안팀 |

### 6.2 업데이트 절차
```bash
# 1. 백업 수행
docker compose exec backup /backup.sh backup

# 2. 서비스 중지
docker compose stop openproject gitea

# 3. 이미지 업데이트
docker compose pull

# 4. 서비스 재시작
docker compose up -d

# 5. 상태 확인
docker compose ps
curl http://localhost:9000/health
```

---

## 7. 접속 정보

### 7.1 서비스 URL
| 서비스 | URL | 설명 |
|--------|-----|------|
| 통합 포털 | http://localhost:9000 | 메인 진입점 |
| OpenProject | http://localhost:9001 | 프로젝트 관리 |
| Gitea | http://localhost:9002 | Git 저장소 |

### 7.2 초기 계정
```
# OpenProject
- 최초 접속 시 관리자 계정 생성 필요

# Gitea
- 최초 접속 시 설치 마법사 진행
- 관리자 계정 생성 필요
```

---

## 8. 참고 문서

- [OpenProject 공식 문서](https://www.openproject.org/docs/)
- [Gitea 공식 문서](https://docs.gitea.com/)
- [Docker Compose 문서](https://docs.docker.com/compose/)
- [Nginx 설정 가이드](https://nginx.org/en/docs/)
