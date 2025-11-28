# n8n Docker Compose

n8n 워크플로우 자동화 플랫폼을 Docker Compose로 구성하는 프로젝트입니다.

## 프로젝트 구조

```
n8n-docker-compose/
├── docker-compose.yml    # Docker Compose 설정
├── .env                  # 환경 변수 설정
├── config/
│   ├── n8n.conf          # Nginx 설정 파일
│   ├── nginx-install.sh  # Nginx 설정 설치 스크립트
│   └── certbot-install.sh # SSL 인증서 설치 스크립트
└── README.md
```

## 사전 요구사항

- Docker
- Docker Compose
- (선택) Nginx - 리버스 프록시 사용 시
- (선택) 도메인 - HTTPS 설정 시

## 설정

### 1. 환경 변수 설정

`.env` 파일을 열어 환경 변수를 수정합니다:

```bash
# N8N Configuration
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=your_username          # 변경 필요
N8N_BASIC_AUTH_PASSWORD=your_secure_password # 변경 필요
WEBHOOK_URL=http://<your_server_ip_or_domain>:5678/  # 변경 필요
N8N_ENCRYPTION_KEY=your_secret_encryption_key  # 변경 필요
GENERIC_TIMEZONE=Asia/Seoul

# Database Configuration
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=your_db_password    # 변경 필요

# PostgreSQL Configuration
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=your_db_password         # 변경 필요
POSTGRES_DB=n8n
```

## 실행 방법

### 방법 1: n8n만 실행 (외부 PostgreSQL 사용)

외부 PostgreSQL 데이터베이스를 사용하는 경우:

```bash
docker-compose up -d
```

> `.env` 파일에서 `DB_POSTGRESDB_HOST`를 외부 DB 주소로 변경하세요.

### 방법 2: PostgreSQL과 함께 실행 (프로파일 사용)

내장 PostgreSQL을 함께 실행하려면 `--profile postgres` 옵션을 사용합니다:

```bash
docker-compose --profile postgres up -d
```

#### 프로파일 설명

| 명령어 | 설명 |
|--------|------|
| `docker-compose up -d` | n8n만 실행 |
| `docker-compose --profile postgres up -d` | n8n + PostgreSQL 실행 |

#### PostgreSQL 프로파일 중지

```bash
# 전체 중지
docker-compose --profile postgres down

# PostgreSQL만 중지 (n8n은 유지)
docker-compose stop postgres
```

## Nginx 리버스 프록시 설정 (선택)

### 1. Nginx 설정 설치

```bash
cd config
chmod +x nginx-install.sh
sudo ./nginx-install.sh
```

### 2. 도메인 설정

설치 후 Nginx 설정 파일에서 도메인을 수정합니다:

```bash
sudo nano /etc/nginx/sites-available/n8n
# server_name your_domain.com; 부분을 실제 도메인으로 변경
sudo nginx -t
sudo systemctl reload nginx
```

## SSL 인증서 설정 (선택)

Let's Encrypt를 이용한 무료 SSL 인증서 설치:

```bash
cd config
chmod +x certbot-install.sh
sudo ./certbot-install.sh your_domain.com
```

> 자동 갱신은 systemd timer에 의해 자동으로 처리됩니다.

## 보안 및 추가 설정 (선택 사항)

n8n을 안전하게 운영하기 위해 추가 설정을 적용합니다.

### 방화벽 설정

UFW를 사용해 필요한 포트만 엽니다:

```bash
sudo apt install ufw -y
sudo ufw allow 22
sudo ufw allow 5678
sudo ufw enable
```

- SSH(22)와 n8n(5678) 포트를 허용
- HTTPS를 사용할 경우 443 포트를 추가로 엽니다: `sudo ufw allow 443`

### SSL/TLS 설정 (Nginx + Certbot)

HTTPS를 위해 Nginx를 리버스 프록시로 설정합니다.

#### 1. Nginx 설치

```bash
sudo apt install nginx -y
```

#### 2. Nginx 설정 파일 생성

```bash
sudo nano /etc/nginx/sites-available/n8n
```

아래 내용을 추가 (도메인 이름은 `your_domain.com`으로 변경):

```nginx
server {
    listen 80;
    server_name your_domain.com;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### 3. 설정 활성화

```bash
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

#### 4. Certbot으로 SSL 설정

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d your_domain.com
```

Certbot이 자동으로 Nginx 설정을 HTTPS로 업데이트합니다.

#### 5. docker-compose.yml 업데이트

```bash
nano docker-compose.yml
```

- `N8N_PROTOCOL=http`를 `N8N_PROTOCOL=https`로 변경
- `WEBHOOK_URL`을 `https://your_domain.com/`으로 수정

#### 6. 컨테이너 재시작

```bash
docker-compose down
docker-compose up -d
```

## 유용한 명령어

### Docker Compose

```bash
# 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f n8n

# 재시작
docker-compose restart n8n

# 중지 및 삭제
docker-compose down

# 볼륨 포함 삭제 (데이터 삭제 주의!)
docker-compose down -v
```

### Nginx

```bash
# 상태 확인
sudo systemctl status nginx

# 설정 테스트
sudo nginx -t

# 재시작
sudo systemctl reload nginx
```

### SSL 인증서

```bash
# 인증서 상태 확인
sudo certbot certificates

# 갱신 테스트
sudo certbot renew --dry-run

# 자동 갱신 타이머 상태
sudo systemctl status certbot.timer
```

## 접속

- **HTTP**: `http://<서버IP>:5678`
- **HTTPS** (Nginx 설정 후): `https://your_domain.com`

## 출처

- https://rupijun.tistory.com/entry/N8N-Self-Hosting-Docker-compose-구성
- https://svrforum.com/svr/888028