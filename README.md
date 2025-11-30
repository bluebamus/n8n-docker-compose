# n8n Docker Compose

n8n 워크플로우 자동화 플랫폼을 Docker Compose로 구성하는 프로젝트입니다.
Nginx 리버스 프록시, PostgreSQL, Redis를 포함한 프로덕션 환경 구성을 제공합니다.

---

## 목차

- [개요](#개요)
- [아키텍처](#아키텍처)
- [사전 요구사항](#사전-요구사항)
- [프로젝트 구조](#프로젝트-구조)
- [빠른 시작](#빠른-시작)
- [상세 설정](#상세-설정)
  - [환경 변수 설정](#환경-변수-설정)
  - [Nginx 설정](#nginx-설정)
  - [SSL 인증서 설정](#ssl-인증서-설정)
- [실행 및 관리](#실행-및-관리)
- [트러블슈팅](#트러블슈팅)
- [참고 자료](#참고-자료)

---

## 개요

### n8n이란?

[n8n](https://n8n.io/)은 오픈소스 워크플로우 자동화 도구입니다. 다양한 서비스와 애플리케이션을 연결하여 자동화 워크플로우를 구축할 수 있습니다.

### 이 프로젝트의 특징

- **큐 기반 실행 모드**: Redis를 활용한 큐 모드로 대규모 워크플로우 처리 가능
- **PostgreSQL 데이터베이스**: 안정적인 데이터 저장
- **Nginx 리버스 프록시**: HTTPS 지원 및 보안 강화
- **Let's Encrypt SSL**: 무료 SSL 인증서 자동 발급 및 갱신
- **Docker 기반**: 쉬운 배포 및 관리

---

## 아키텍처

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                   Docker Network                        │
                    │                   (172.26.0.0/16)                        │
                    │                                                          │
   ┌────────┐       │   ┌─────────────┐     ┌─────────────┐                   │
   │ Client │──────────▶│   Nginx     │────▶│    n8n      │                   │
   │        │       │   │ :80/:443    │     │   :5678     │                   │
   └────────┘       │   │ 172.26.0.10 │     │ 172.26.0.20 │                   │
                    │   └─────────────┘     └──────┬──────┘                   │
                    │                              │                           │
                    │              ┌───────────────┼───────────────┐          │
                    │              ▼                               ▼          │
                    │   ┌─────────────┐                 ┌─────────────┐       │
                    │   │ PostgreSQL  │                 │    Redis    │       │
                    │   │   :5432     │                 │   :6379     │       │
                    │   │ 172.26.0.30 │                 │ 172.26.0.40 │       │
                    │   └─────────────┘                 └─────────────┘       │
                    │                                                          │
                    └─────────────────────────────────────────────────────────┘
```

### 컴포넌트 설명

| 서비스 | 이미지 | IP 주소 | 포트 | 역할 |
|--------|--------|---------|------|------|
| **webserver** | nginx:latest (커스텀) | 172.26.0.10 | 80, 443 | 리버스 프록시, SSL 처리 |
| **n8n** | n8nio/n8n:latest | 172.26.0.20 | 5678 | 워크플로우 자동화 엔진 |
| **postgres** | postgres:latest | 172.26.0.30 | 5432 | 워크플로우/실행 데이터 저장 |
| **redis** | redis:alpine | 172.26.0.40 | 6379 | 큐 관리, 세션 저장 |

---

## 사전 요구사항

### 필수 요구사항

- **Docker**: 20.10.0 이상
- **Docker Compose**: 2.0.0 이상
- **메모리**: 최소 2GB RAM (권장 4GB)
- **디스크**: 최소 10GB 여유 공간

### 선택 요구사항 (HTTPS 사용 시)

- **도메인**: 공인 도메인 (Let's Encrypt 인증서 발급용)
- **포트 개방**: 80, 443 포트

### 설치 확인

```bash
# Docker 버전 확인
docker --version

# Docker Compose 버전 확인
docker compose version
```

---

## 프로젝트 구조

```
n8n-docker-compose/
├── docker-compose.yml          # Docker Compose 메인 설정 파일
├── Dockerfile-nginx            # Nginx 커스텀 이미지 빌드 파일
├── .env                        # 환경 변수 설정 (민감 정보 포함)
├── init-script.sh              # 초기화 스크립트
├── README.md                   # 이 문서
│
├── config/                     # 설정 파일 디렉토리
│   ├── n8n/                    # n8n 커스텀 설정
│   ├── nginx/                  # Nginx 설정
│   │   ├── proxy/              # 프록시 설정
│   │   │   ├── conf.d/         # 사이트 설정 파일
│   │   │   ├── nginx_conf/     # nginx.conf 메인 설정
│   │   │   └── proxy_params/   # 프록시 파라미터
│   │   └── ssl/                # SSL 관련 스크립트
│   │       └── letsencrypt.sh  # Let's Encrypt 인증서 발급 스크립트
│   ├── postgres/               # PostgreSQL 설정
│   └── redis/                  # Redis 설정
│
├── storage/                    # 영구 데이터 저장소
│   ├── n8n_storage/            # n8n 워크플로우 데이터
│   ├── nginx_storage/          # Nginx 설정 및 인증서
│   │   ├── etc/nginx/          # Nginx 설정 파일
│   │   ├── etc/ssl/            # SSL 인증서
│   │   └── www/                # 웹 루트 (ACME 챌린지용)
│   ├── postgres_storage/       # PostgreSQL 데이터
│   └── redis_storage/          # Redis 데이터
│
└── logs/                       # 로그 디렉토리
```

---

## 빠른 시작

### 1단계: 저장소 복제

```bash
git clone <repository-url>
cd n8n-docker-compose
```

### 2단계: 초기화 스크립트 실행

```bash
# 스크립트에 실행 권한 부여
chmod +x init-script.sh

# 초기화 실행 (.gitkeep 파일 정리)
./init-script.sh
```

### 3단계: 환경 변수 설정

```bash
# .env 파일 편집
nano .env
```

**필수 변경 항목:**
- `N8N_BASIC_AUTH_USER`: 관리자 사용자명
- `N8N_BASIC_AUTH_PASSWORD`: 관리자 비밀번호
- `WEBHOOK_URL`: 외부 접속 URL
- `N8N_ENCRYPTION_KEY`: 암호화 키
- `POSTGRES_PASSWORD`: 데이터베이스 비밀번호
- `POSTGRES_NON_ROOT_PASSWORD`: n8n용 데이터베이스 비밀번호

### 4단계: 서비스 시작

```bash
# 전체 서비스 시작
docker compose up -d

# 로그 확인
docker compose logs -f
```

### 5단계: 접속 확인

- **HTTP**: `http://<서버IP>:5678`
- **HTTPS** (Nginx 설정 후): `https://your-domain.com`

---

## 상세 설정

### 환경 변수 설정

`.env` 파일의 모든 변수에 대한 상세 설명입니다.

#### N8N 기본 설정

| 변수명 | 기본값 | 필수 변경 | 설명 |
|--------|--------|:---------:|------|
| `N8N_PORT` | 5678 | - | n8n 웹 인터페이스 포트 |
| `N8N_PROTOCOL` | http | - | 프로토콜 (http/https) |

#### N8N 인증 설정

| 변수명 | 기본값 | 필수 변경 | 설명 |
|--------|--------|:---------:|------|
| `N8N_BASIC_AUTH_ACTIVE` | true | - | Basic Auth 활성화 여부 |
| `N8N_BASIC_AUTH_USER` | your_username | O | 관리자 사용자명 |
| `N8N_BASIC_AUTH_PASSWORD` | your_secure_password | O | 관리자 비밀번호 |

#### 웹훅 및 보안 설정

| 변수명 | 기본값 | 필수 변경 | 설명 |
|--------|--------|:---------:|------|
| `WEBHOOK_URL` | http://... | O | 외부 웹훅 호출 URL |
| `N8N_ENCRYPTION_KEY` | your_secret... | O | 자격증명 암호화 키 |
| `GENERIC_TIMEZONE` | Asia/Seoul | - | 시스템 시간대 |

#### PostgreSQL 데이터베이스 설정

| 변수명 | 기본값 | 필수 변경 | 설명 |
|--------|--------|:---------:|------|
| `POSTGRES_USER` | n8n_user | - | DB 관리자 계정 |
| `POSTGRES_PASSWORD` | your_db_password | O | DB 관리자 비밀번호 |
| `POSTGRES_DB` | n8n | - | 데이터베이스 이름 |
| `POSTGRES_NON_ROOT_USER` | n8n_user | - | n8n용 DB 계정 |
| `POSTGRES_NON_ROOT_PASSWORD` | your_db_password | O | n8n용 DB 비밀번호 |

#### 암호화 키 생성 방법

```bash
# Linux/Mac
openssl rand -hex 32

# 또는 Python 사용
python3 -c "import secrets; print(secrets.token_hex(32))"
```

---

### Nginx 설정

#### 기본 HTTP 설정

프로젝트에는 기본 Nginx 설정이 포함되어 있습니다. `config/nginx/proxy/conf.d/n8n.conf` 파일을 확인하세요.

#### HTTPS 설정 활성화

1. **도메인 DNS 설정**: 서버 IP를 도메인에 연결
2. **Nginx 컨테이너 접속**:
   ```bash
   docker exec -it nginx-gunicorn-webserver bash
   ```
3. **SSL 스크립트 실행**:
   ```bash
   /script/ssl/letsencrypt.sh
   ```
4. **프롬프트 입력**:
   - `webroot_folder`: 웹 루트 폴더명 (예: `html`)
   - `domain`: 도메인 (예: `example.com www.example.com`)
   - `email`: 인증서 알림용 이메일

---

### SSL 인증서 설정

#### Let's Encrypt 인증서 발급

```bash
# Nginx 컨테이너 접속
docker exec -it nginx-gunicorn-webserver bash

# SSL 스크립트 실행
/script/ssl/letsencrypt.sh
```

#### 스크립트 동작 과정

1. webroot 폴더 생성 및 권한 설정
2. ACME 챌린지 디렉토리 생성 (`.well-known/acme-challenge`)
3. DH 파라미터 생성 (4096bit)
4. certbot을 통한 인증서 발급
5. 자동 갱신 cron job 등록 (매주 월요일 05:00)

#### 인증서 자동 갱신

인증서는 자동으로 갱신됩니다. 수동 갱신이 필요한 경우:

```bash
docker exec nginx-gunicorn-webserver certbot renew
```

#### 인증서 상태 확인

```bash
docker exec nginx-gunicorn-webserver certbot certificates
```

---

## 실행 및 관리

### Docker Compose 명령어

#### 서비스 시작/중지

```bash
# 전체 서비스 시작 (백그라운드)
docker compose up -d

# 전체 서비스 중지
docker compose down

# 특정 서비스만 재시작
docker compose restart n8n

# 서비스 상태 확인
docker compose ps
```

#### 로그 확인

```bash
# 전체 로그 확인
docker compose logs

# 실시간 로그 확인
docker compose logs -f

# 특정 서비스 로그 확인
docker compose logs -f n8n

# 최근 100줄만 확인
docker compose logs --tail=100 n8n
```

#### 컨테이너 접속

```bash
# n8n 컨테이너 접속
docker exec -it n8n sh

# Nginx 컨테이너 접속
docker exec -it nginx-gunicorn-webserver bash

# PostgreSQL 접속
docker exec -it n8n_postgres psql -U n8n_user -d n8n

# Redis 접속
docker exec -it n8n_redis redis-cli
```

### 백업 및 복원

#### 데이터 백업

```bash
# 전체 storage 백업
tar -czvf backup_$(date +%Y%m%d).tar.gz storage/

# PostgreSQL만 백업
docker exec n8n_postgres pg_dump -U n8n_user n8n > backup_db_$(date +%Y%m%d).sql
```

#### 데이터 복원

```bash
# storage 복원
tar -xzvf backup_20231201.tar.gz

# PostgreSQL 복원
cat backup_db_20231201.sql | docker exec -i n8n_postgres psql -U n8n_user -d n8n
```

### 업데이트

```bash
# 이미지 업데이트
docker compose pull

# 서비스 재시작 (새 이미지 적용)
docker compose up -d

# 오래된 이미지 정리
docker image prune -f
```

---

## 트러블슈팅

### 일반적인 문제

#### 서비스가 시작되지 않음

```bash
# 상태 확인
docker compose ps

# 상세 로그 확인
docker compose logs --tail=50

# 헬스체크 상태 확인
docker inspect n8n_postgres | grep -A 10 Health
docker inspect n8n_redis | grep -A 10 Health
```

#### 데이터베이스 연결 실패

```bash
# PostgreSQL 상태 확인
docker exec n8n_postgres pg_isready -U n8n_user -d n8n

# 네트워크 연결 확인
docker exec n8n ping -c 3 postgres
```

#### 웹훅이 동작하지 않음

1. `WEBHOOK_URL` 설정 확인
2. 방화벽 설정 확인 (80, 443 포트)
3. 도메인 DNS 설정 확인

```bash
# 외부에서 접근 테스트
curl -I https://your-domain.com/webhook/test
```

#### SSL 인증서 발급 실패

1. 도메인이 서버 IP를 가리키는지 확인
2. 80 포트가 외부에서 접근 가능한지 확인
3. Nginx가 정상 실행 중인지 확인

```bash
# DNS 확인
nslookup your-domain.com

# 포트 확인
curl -I http://your-domain.com/.well-known/acme-challenge/test
```

### 로그 위치

| 서비스 | 로그 위치 |
|--------|----------|
| n8n | `docker compose logs n8n` |
| Nginx | `./logs/` 또는 `docker compose logs webserver` |
| PostgreSQL | `docker compose logs postgres` |
| Redis | `docker compose logs redis` |

### 리소스 모니터링

```bash
# 컨테이너 리소스 사용량
docker stats

# 디스크 사용량
docker system df
```

---

## 보안 권장사항

### 필수 보안 조치

1. **강력한 비밀번호 사용**: 모든 비밀번호는 최소 16자 이상, 특수문자 포함
2. **암호화 키 안전 보관**: `N8N_ENCRYPTION_KEY`는 분실 시 복구 불가
3. **HTTPS 사용**: 프로덕션 환경에서는 반드시 HTTPS 사용
4. **정기적인 백업**: 최소 일 1회 자동 백업 설정

### 방화벽 설정 (UFW)

```bash
# UFW 설치 및 활성화
sudo apt install ufw -y

# 기본 정책 설정
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 필요한 포트만 허용
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS

# UFW 활성화
sudo ufw enable

# 상태 확인
sudo ufw status
```

### .env 파일 보호

```bash
# 파일 권한 설정 (소유자만 읽기/쓰기)
chmod 600 .env

# Git에서 제외 확인
cat .gitignore | grep .env
```

---

## 참고 자료

### 공식 문서

- [n8n 공식 문서](https://docs.n8n.io/)
- [n8n Docker 설치 가이드](https://docs.n8n.io/hosting/installation/docker/)
- [n8n 환경 변수 목록](https://docs.n8n.io/hosting/configuration/environment-variables/)

### 관련 링크

- [n8n GitHub](https://github.com/n8n-io/n8n)
- [n8n 커뮤니티](https://community.n8n.io/)
- [Docker Compose 문서](https://docs.docker.com/compose/)
- [Let's Encrypt](https://letsencrypt.org/)

### 참고한 자료

- https://rupijun.tistory.com/entry/N8N-Self-Hosting-Docker-compose-구성
- https://svrforum.com/svr/888028
- https://wikidocs.net/book/18092

---

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.
