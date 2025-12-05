# MAXOps

# 컨테이너 중지 및 삭제

docker compose down

# 기존 데이터 삭제

rm -rf data/postgres/\*

# 다시 시작

docker compose up -d

# 로그 확인

docker compose logs -f postgres

> maxops-postgres | 2025-12-05 10:29:48.445 KST [89] FATAL: database "gitea" does not exist
> maxops-postgres | 2025-12-05 10:29:51.448 KST [97] FATAL: database "gitea" does not exist
> maxops-postgres | 2025-12-05 10:29:54.451 KST [102] FATAL: database "gitea" does not exist
> maxops-postgres | 2025-12-05 10:29:57.455 KST [104] FATAL: database "gitea" does not exist
> maxops-postgres | 2025-12-05 10:30:00.458 KST [107] FATAL: database "gitea" does not exis

● Gitea 데이터베이스를 수동으로 생성하세요:

docker compose exec postgres psql -U maxops -d openproject -c "CREATE DATABASE gitea;"

그 후 Gitea 재시작:

docker compose restart gitea

둘 다 재시작하세요:

docker compose restart openproject gitea

또는 .env 파일로 관리하려면:

# .env 파일에 추가

OPENPROJECT_HOST=172.168.30.21:9001
GITEA_DOMAIN=172.168.30.21
GITEA_SSH_DOMAIN=172.168.30.21
GITEA_ROOT_URL=http://172.168.30.21:9002/

그 후:
docker compose up -d
