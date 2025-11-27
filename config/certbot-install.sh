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
    echo -e "${RED}Error: Please run as root${NC}"
    exit 1
fi

# Check if domain argument is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Domain name is required${NC}"
    echo "Usage: ./certbot-install.sh your_domain.com"
    exit 1
fi

DOMAIN=$1

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Certbot SSL Installation Script${NC}"
echo -e "${GREEN}  (Alpine Linux)${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Domain: ${YELLOW}${DOMAIN}${NC}"
echo ""

# Step 1: Update package list
echo -e "${GREEN}[1/4] Updating package list...${NC}"
apk update

# Step 2: Install Certbot and Nginx plugin
echo -e "${GREEN}[2/4] Installing Certbot and Nginx plugin...${NC}"
apk add certbot certbot-nginx

# Step 3: Obtain SSL certificate
echo -e "${GREEN}[3/4] Obtaining SSL certificate for ${DOMAIN}...${NC}"
certbot --nginx -d "$DOMAIN"

# Step 4: Setup auto-renewal via cron
echo -e "${GREEN}[4/4] Setting up automatic certificate renewal...${NC}"

# Create cron job for auto-renewal
CRON_JOB="0 0,12 * * * /usr/bin/certbot renew --quiet"

# Check if cron is installed
if ! command -v crond > /dev/null 2>&1; then
    echo -e "${YELLOW}Installing crond...${NC}"
    apk add dcron
    rc-service dcron start
    rc-update add dcron default
fi

# Add cron job if not exists
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo -e "${GREEN}Cron job added for automatic renewal${NC}"
else
    echo -e "${YELLOW}Cron job for certbot renewal already exists${NC}"
fi

# Test renewal process
echo -e "${YELLOW}Testing renewal process...${NC}"
certbot renew --dry-run

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "SSL certificate installed for: ${YELLOW}${DOMAIN}${NC}"
echo ""
echo -e "${GREEN}Certificate Info:${NC}"
echo "  - Certificate path: /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
echo "  - Private key path: /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
echo ""
echo -e "${GREEN}Auto-renewal:${NC}"
echo "  - Cron job runs twice daily (00:00 and 12:00)"
echo "  - Check cron: crontab -l"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  - Check certificate status: certbot certificates"
echo "  - Manual renewal test: certbot renew --dry-run"
echo "  - Force renewal: certbot renew --force-renewal"
echo ""
