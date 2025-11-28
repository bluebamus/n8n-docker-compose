#!/bin/sh

# Certbot SSL Certificate Installation Script for n8n (Alpine Linux)
# Usage: ./certbot-install.sh your_domain.com

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

# Check if domain argument is provided
if [ -z "$1" ]; then
    printf "${RED}Error: Domain name is required${NC}\n"
    echo "Usage: ./certbot-install.sh your_domain.com"
    exit 1
fi

DOMAIN=$1

printf "${GREEN}========================================${NC}\n"
printf "${GREEN}  Certbot SSL Installation Script${NC}\n"
printf "${GREEN}  (Alpine Linux)${NC}\n"
printf "${GREEN}========================================${NC}\n"
echo ""
printf "Domain: ${YELLOW}${DOMAIN}${NC}\n"
echo ""

# Step 1: Update package list
printf "${GREEN}[1/4] Updating package list...${NC}\n"
apk update

# Step 2: Install Certbot and Nginx plugin
printf "${GREEN}[2/4] Installing Certbot and Nginx plugin...${NC}\n"
apk add certbot certbot-nginx

# Step 3: Obtain SSL certificate
printf "${GREEN}[3/4] Obtaining SSL certificate for ${DOMAIN}...${NC}\n"
certbot --nginx -d "$DOMAIN"

# Step 4: Setup auto-renewal via cron
printf "${GREEN}[4/4] Setting up automatic certificate renewal...${NC}\n"

# Create cron job for auto-renewal
CRON_JOB="0 0,12 * * * /usr/bin/certbot renew --quiet"

# Check if cron is installed (Alpine uses crond from busybox or dcron)
if ! command -v crond > /dev/null 2>&1; then
    printf "${YELLOW}Installing dcron...${NC}\n"
    apk add dcron
fi

# Start crond if not running
if ! pgrep -x crond > /dev/null 2>&1; then
    printf "${YELLOW}Starting crond...${NC}\n"
    crond
fi

# Add cron job if not exists
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    printf "${GREEN}Cron job added for automatic renewal${NC}\n"
else
    printf "${YELLOW}Cron job for certbot renewal already exists${NC}\n"
fi

# Test renewal process
printf "${YELLOW}Testing renewal process...${NC}\n"
certbot renew --dry-run

echo ""
printf "${GREEN}========================================${NC}\n"
printf "${GREEN}  Installation Complete!${NC}\n"
printf "${GREEN}========================================${NC}\n"
echo ""
printf "SSL certificate installed for: ${YELLOW}${DOMAIN}${NC}\n"
echo ""
printf "${GREEN}Certificate Info:${NC}\n"
echo "  - Certificate path: /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
echo "  - Private key path: /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
echo ""
printf "${GREEN}Auto-renewal:${NC}\n"
echo "  - Cron job runs twice daily (00:00 and 12:00)"
echo "  - Check cron: crontab -l"
echo ""
printf "${YELLOW}Useful commands:${NC}\n"
echo "  - Check certificate status: certbot certificates"
echo "  - Manual renewal test: certbot renew --dry-run"
echo "  - Force renewal: certbot renew --force-renewal"
echo ""
