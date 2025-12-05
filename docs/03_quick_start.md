# MaxOps 빠른 시작 가이드

## 1. 사전 요구사항

### 1.1 시스템 요구사항
- **OS**: Linux (Ubuntu 20.04+ 권장), macOS, Windows (WSL2)
- **CPU**: 2코어 이상
- **RAM**: 4GB 이상 (8GB 권장)
- **디스크**: 20GB 이상 여유 공간

### 1.2 필수 소프트웨어
```bash
# Docker 버전 확인
docker --version  # 20.x 이상 필요

# Docker Compose 버전 확인
docker compose version  # 2.x 이상 필요
```

---

## 2. 설치 단계

### Step 1: 프로젝트 클론 또는 다운로드
```bash
# 프로젝트 디렉토리로 이동
cd /home/hklee/project/maxoperation
```

### Step 2: 환경 변수 설정
```bash
# 환경 변수 파일 복사
cp .env.example .env

# 환경 변수 편집
vi .env
```

**필수 수정 항목**
```bash
# 반드시 변경해야 할 값들
POSTGRES_PASSWORD=안전한_비밀번호_입력
OPENPROJECT_SECRET=64자_이상의_랜덤_문자열
GITEA_SECRET_KEY=32자_이상의_랜덤_문자열
GITEA_INTERNAL_TOKEN=랜덤_토큰_값
```

**시크릿 키 생성 방법**
```bash
# OpenProject 시크릿 (64자)
openssl rand -hex 64

# Gitea 시크릿 (32자)
openssl rand -hex 32
```

### Step 3: 서비스 시작
```bash
# 전체 서비스 시작
docker compose up -d

# 시작 상태 확인
docker compose ps
```

### Step 4: 초기화 대기
```bash
# 로그 확인 (초기화 완료까지 약 2-3분)
docker compose logs -f openproject gitea

# Ctrl+C로 로그 종료
```

---

## 3. 초기 설정

### 3.1 OpenProject 설정

1. **브라우저 접속**: http://localhost:9001

2. **관리자 계정 생성**
   - 이메일, 비밀번호 입력
   - 언어: 한국어 선택

3. **기본 프로젝트 생성**
   - Administration > Projects > New Project
   - 프로젝트명 입력
   - 템플릿 선택 (Scrum, Basic 등)

### 3.2 Gitea 설정

1. **브라우저 접속**: http://localhost:9002

2. **설치 마법사 진행**
   - 데이터베이스: PostgreSQL (자동 설정됨)
   - 관리자 계정 생성
   - 사이트 제목: MaxOps Git

3. **조직 생성**
   - 우측 상단 + > New Organization
   - 조직명 입력

4. **저장소 생성**
   - New Repository
   - 저장소명 입력

---

## 4. 서비스 접속 정보

| 서비스 | URL | 설명 |
|--------|-----|------|
| 통합 포털 | http://localhost:9000 | 서비스 선택 |
| OpenProject | http://localhost:9001 | 프로젝트 관리 |
| Gitea | http://localhost:9002 | Git 저장소 |

---

## 5. 기본 명령어

### 서비스 관리
```bash
# 상태 확인
docker compose ps

# 전체 중지
docker compose stop

# 전체 시작
docker compose start

# 재시작
docker compose restart

# 로그 확인
docker compose logs -f --tail=100
```

### 데이터 백업
```bash
# 수동 백업 실행
docker compose exec backup /backup.sh backup

# 백업 파일 확인
ls -la backup/daily/
```

---

## 6. 문제 해결

### 서비스가 시작되지 않는 경우
```bash
# 로그 확인
docker compose logs openproject

# 컨테이너 재시작
docker compose restart openproject
```

### 포트 충돌 발생
```bash
# 사용 중인 포트 확인
sudo lsof -i :9001

# docker-compose.yml에서 포트 변경
```

### 메모리 부족
```bash
# Docker 메모리 사용량 확인
docker stats

# 불필요한 컨테이너 정리
docker system prune
```

---

## 7. 다음 단계

1. **Webhook 설정**: Gitea → OpenProject 연동
2. **CI/CD 설정**: Gitea Actions Runner 등록
3. **사용자 추가**: 팀원 계정 생성 및 권한 부여
4. **백업 자동화**: Cron 작업 설정

자세한 내용은 `02_implementation_plan.md` 참조
