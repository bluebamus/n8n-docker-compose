#!/bin/bash

# Certbot SSL Certificate Installation Script for n8n
# Usage: sudo ./certbot-install.sh your_domain.com

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root (sudo)${NC}"
    exit 1
fi

# Check if domain argument is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Domain name is required${NC}"
    echo "Usage: sudo ./certbot-install.sh your_domain.com"
    exit 1
fi

DOMAIN=$1

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Certbot SSL Installation Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Domain: ${YELLOW}${DOMAIN}${NC}"
echo ""

# Step 1: Update package list
echo -e "${GREEN}[1/4] Updating package list...${NC}"
apt update

# Step 2: Install Certbot and Nginx plugin
echo -e "${GREEN}[2/4] Installing Certbot and Nginx plugin...${NC}"
apt install certbot python3-certbot-nginx -y

# Step 3: Obtain SSL certificate
echo -e "${GREEN}[3/4] Obtaining SSL certificate for ${DOMAIN}...${NC}"
certbot --nginx -d "$DOMAIN"

# Step 4: Verify auto-renewal setup
echo -e "${GREEN}[4/4] Verifying automatic certificate renewal...${NC}"

# Check if systemd timer exists (modern certbot installations include this)
if systemctl list-unit-files | grep -q "certbot.timer"; then
    systemctl enable certbot.timer
    systemctl start certbot.timer
    echo -e "${GREEN}Certbot systemd timer is active (auto-renewal enabled)${NC}"
    TIMER_ACTIVE=true
else
    TIMER_ACTIVE=false
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
if [ "$TIMER_ACTIVE" = true ]; then
    echo "  - Systemd timer handles automatic renewal (twice daily)"
    echo "  - Check status: systemctl status certbot.timer"
else
    echo -e "  ${YELLOW}Warning: Systemd timer not found${NC}"
    echo "  - Consider adding a cron job manually:"
    echo "    0 0,12 * * * /usr/bin/certbot renew --quiet"
fi
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  - Check certificate status: sudo certbot certificates"
echo "  - Check timer status: sudo systemctl status certbot.timer"
echo "  - Manual renewal test: sudo certbot renew --dry-run"
echo "  - Force renewal: sudo certbot renew --force-renewal"
echo ""
