#!/bin/sh

# Nginx Configuration Install Script for n8n (Alpine Linux / Docker)
# Usage: ./nginx-install.sh [domain] [--https]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    printf "${RED}Error: Please run as root${NC}\n"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAIN="${1:-your_domain.com}"
USE_HTTPS=false

# Check for --https flag
for arg in "$@"; do
    if [ "$arg" = "--https" ]; then
        USE_HTTPS=true
    fi
done

# Select config file based on HTTPS flag
if [ "$USE_HTTPS" = true ]; then
    CONF_FILE="${SCRIPT_DIR}/n8n_https.conf"
    CONF_NAME="n8n_https.conf"
else
    CONF_FILE="${SCRIPT_DIR}/n8n.conf"
    CONF_NAME="n8n.conf"
fi

printf "${GREEN}========================================${NC}\n"
printf "${GREEN}  Nginx Configuration Install Script${NC}\n"
printf "${GREEN}  (Alpine Linux / Docker)${NC}\n"
printf "${GREEN}========================================${NC}\n"
echo ""
if [ "$USE_HTTPS" = true ]; then
    printf "Mode: ${YELLOW}HTTPS${NC}\n"
else
    printf "Mode: ${YELLOW}HTTP${NC}\n"
fi
echo ""

# Check if config file exists
if [ ! -f "$CONF_FILE" ]; then
    printf "${RED}Error: ${CONF_NAME} not found in ${SCRIPT_DIR}${NC}\n"
    exit 1
fi

# Check if nginx is installed
if ! command -v nginx > /dev/null 2>&1; then
    printf "${YELLOW}Nginx is not installed. Installing...${NC}\n"
    apk update
    apk add nginx
fi

# Create nginx directories if they don't exist
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# Check if nginx.conf includes sites-enabled
if ! grep -q "include /etc/nginx/sites-enabled" /etc/nginx/nginx.conf; then
    printf "${YELLOW}Adding sites-enabled include to nginx.conf...${NC}\n"
    sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
fi

# For HTTPS mode, create certbot webroot directory
if [ "$USE_HTTPS" = true ]; then
    mkdir -p /var/www/certbot
fi

# Step 1: Copy config file to sites-available and update domain
printf "${GREEN}[1/6] Copying ${CONF_NAME} to /etc/nginx/sites-available/...${NC}\n"
cp "$CONF_FILE" /etc/nginx/sites-available/n8n

# Step 2: Update server_name if domain provided
if [ "$DOMAIN" != "your_domain.com" ]; then
    printf "${GREEN}[2/6] Updating server_name to ${DOMAIN}...${NC}\n"
    sed -i "s/server_name your_domain.com;/server_name ${DOMAIN};/g" /etc/nginx/sites-available/n8n
    # Update SSL certificate paths for HTTPS mode
    if [ "$USE_HTTPS" = true ]; then
        sed -i "s|/etc/letsencrypt/live/your_domain.com/|/etc/letsencrypt/live/${DOMAIN}/|g" /etc/nginx/sites-available/n8n
    fi
else
    printf "${YELLOW}[2/6] Using default domain. Update /etc/nginx/sites-available/n8n later.${NC}\n"
fi

# Step 3: Create symbolic link to sites-enabled
printf "${GREEN}[3/6] Creating symbolic link to sites-enabled...${NC}\n"
if [ -L /etc/nginx/sites-enabled/n8n ]; then
    printf "${YELLOW}Symbolic link already exists. Removing old link...${NC}\n"
    rm /etc/nginx/sites-enabled/n8n
fi
ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Step 4: Test nginx configuration
printf "${GREEN}[4/6] Testing Nginx configuration...${NC}\n"
if nginx -t; then
    printf "${GREEN}Nginx configuration test passed!${NC}\n"
else
    printf "${RED}Nginx configuration test failed!${NC}\n"
    printf "${YELLOW}Removing invalid configuration...${NC}\n"
    rm /etc/nginx/sites-enabled/n8n
    rm /etc/nginx/sites-available/n8n
    exit 1
fi

# Step 5: Generate self-signed certificate for initial HTTPS setup (if needed)
if [ "$USE_HTTPS" = true ]; then
    printf "${GREEN}[5/6] Checking SSL certificates...${NC}\n"
    SSL_CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"

    if [ ! -f "${SSL_CERT_DIR}/fullchain.pem" ]; then
        printf "${YELLOW}SSL certificates not found. Generating self-signed certificate...${NC}\n"
        mkdir -p "$SSL_CERT_DIR"

        # Generate self-signed certificate for initial setup
        apk add --no-cache openssl 2>/dev/null || true
        openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
            -keyout "${SSL_CERT_DIR}/privkey.pem" \
            -out "${SSL_CERT_DIR}/fullchain.pem" \
            -subj "/CN=${DOMAIN}"

        printf "${GREEN}Self-signed certificate generated.${NC}\n"
        printf "${YELLOW}Note: Run certbot-install.sh to obtain a valid Let's Encrypt certificate.${NC}\n"
    else
        printf "${GREEN}SSL certificates found.${NC}\n"
    fi
else
    printf "${GREEN}[5/6] Skipping SSL setup (HTTP mode)...${NC}\n"
fi

# Step 6: Start/Restart nginx (handle both Docker and standard Alpine)
printf "${GREEN}[6/6] Starting Nginx...${NC}\n"

# Check if we're in a Docker container (no init system)
if [ -f /.dockerenv ] || ! command -v rc-service > /dev/null 2>&1; then
    # Docker environment - use nginx directly
    if pgrep -x nginx > /dev/null 2>&1; then
        printf "${YELLOW}Reloading Nginx...${NC}\n"
        nginx -s reload
    else
        printf "${YELLOW}Starting Nginx in foreground mode...${NC}\n"
        nginx
    fi
else
    # Standard Alpine with OpenRC
    if rc-service nginx status > /dev/null 2>&1; then
        rc-service nginx restart
    else
        rc-service nginx start
    fi
    # Enable nginx on boot
    rc-update add nginx default 2>/dev/null || true
fi

echo ""
printf "${GREEN}========================================${NC}\n"
printf "${GREEN}  Installation Complete!${NC}\n"
printf "${GREEN}========================================${NC}\n"
echo ""
printf "Configuration file: ${YELLOW}/etc/nginx/sites-available/n8n${NC}\n"
printf "Symbolic link: ${YELLOW}/etc/nginx/sites-enabled/n8n${NC}\n"
echo ""
printf "${YELLOW}Next steps:${NC}\n"
if [ "$DOMAIN" = "your_domain.com" ]; then
    echo "  1. Update 'server_name' in /etc/nginx/sites-available/n8n"
    echo "  2. Run: nginx -t && nginx -s reload"
fi
if [ "$USE_HTTPS" = true ]; then
    echo "  - Run certbot-install.sh ${DOMAIN} to obtain valid SSL certificate"
else
    echo "  - Run nginx-install.sh ${DOMAIN} --https to enable HTTPS"
fi
echo ""
printf "${YELLOW}Useful commands:${NC}\n"
echo "  - Test config: nginx -t"
echo "  - Reload Nginx: nginx -s reload"
echo "  - View Nginx logs: tail -f /var/log/nginx/error.log"
echo ""
