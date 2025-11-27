#!/bin/sh

# Nginx Configuration Install Script for n8n (Alpine Linux)
# Usage: ./nginx-install.sh [domain]

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/n8n.conf"
DOMAIN="${1:-your_domain.com}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Nginx Configuration Install Script${NC}"
echo -e "${GREEN}  (Alpine Linux)${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if n8n.conf exists
if [ ! -f "$CONF_FILE" ]; then
    echo -e "${RED}Error: n8n.conf not found in ${SCRIPT_DIR}${NC}"
    exit 1
fi

# Check if nginx is installed
if ! command -v nginx > /dev/null 2>&1; then
    echo -e "${YELLOW}Nginx is not installed. Installing...${NC}"
    apk update
    apk add nginx
fi

# Create nginx directories if they don't exist
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# Check if nginx.conf includes sites-enabled
if ! grep -q "include /etc/nginx/sites-enabled" /etc/nginx/nginx.conf; then
    echo -e "${YELLOW}Adding sites-enabled include to nginx.conf...${NC}"
    sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
fi

# Step 1: Copy config file to sites-available and update domain
echo -e "${GREEN}[1/5] Copying n8n.conf to /etc/nginx/sites-available/...${NC}"
cp "$CONF_FILE" /etc/nginx/sites-available/n8n

# Step 2: Update server_name if domain provided
if [ "$DOMAIN" != "your_domain.com" ]; then
    echo -e "${GREEN}[2/5] Updating server_name to ${DOMAIN}...${NC}"
    sed -i "s/server_name your_domain.com;/server_name ${DOMAIN};/" /etc/nginx/sites-available/n8n
else
    echo -e "${YELLOW}[2/5] Using default domain. Update /etc/nginx/sites-available/n8n later.${NC}"
fi

# Step 3: Create symbolic link to sites-enabled
echo -e "${GREEN}[3/5] Creating symbolic link to sites-enabled...${NC}"
if [ -L /etc/nginx/sites-enabled/n8n ]; then
    echo -e "${YELLOW}Symbolic link already exists. Removing old link...${NC}"
    rm /etc/nginx/sites-enabled/n8n
fi
ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Step 4: Test nginx configuration
echo -e "${GREEN}[4/5] Testing Nginx configuration...${NC}"
if nginx -t; then
    echo -e "${GREEN}Nginx configuration test passed!${NC}"
else
    echo -e "${RED}Nginx configuration test failed!${NC}"
    echo -e "${YELLOW}Removing invalid configuration...${NC}"
    rm /etc/nginx/sites-enabled/n8n
    rm /etc/nginx/sites-available/n8n
    exit 1
fi

# Step 5: Start/Restart nginx
echo -e "${GREEN}[5/5] Starting Nginx...${NC}"
if rc-service nginx status > /dev/null 2>&1; then
    rc-service nginx restart
else
    rc-service nginx start
fi

# Enable nginx on boot
rc-update add nginx default 2>/dev/null || true

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Configuration file: ${YELLOW}/etc/nginx/sites-available/n8n${NC}"
echo -e "Symbolic link: ${YELLOW}/etc/nginx/sites-enabled/n8n${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
if [ "$DOMAIN" = "your_domain.com" ]; then
    echo "  1. Update 'server_name' in /etc/nginx/sites-available/n8n"
    echo "  2. Run: nginx -t && rc-service nginx reload"
fi
echo "  - Run certbot-install.sh to enable HTTPS"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  - Check Nginx status: rc-service nginx status"
echo "  - Reload Nginx: rc-service nginx reload"
echo "  - View Nginx logs: tail -f /var/log/nginx/error.log"
echo ""
