#!/bin/sh

# Nginx Configuration Install Script for n8n (Alpine Linux / Docker)
# Usage: ./nginx-install.sh [domain]

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
CONF_FILE="${SCRIPT_DIR}/n8n.conf"
DOMAIN="${1:-your_domain.com}"

printf "${GREEN}========================================${NC}\n"
printf "${GREEN}  Nginx Configuration Install Script${NC}\n"
printf "${GREEN}  (Alpine Linux / Docker)${NC}\n"
printf "${GREEN}========================================${NC}\n"
echo ""

# Check if n8n.conf exists
if [ ! -f "$CONF_FILE" ]; then
    printf "${RED}Error: n8n.conf not found in ${SCRIPT_DIR}${NC}\n"
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

# Step 1: Copy config file to sites-available and update domain
printf "${GREEN}[1/5] Copying n8n.conf to /etc/nginx/sites-available/...${NC}\n"
cp "$CONF_FILE" /etc/nginx/sites-available/n8n

# Step 2: Update server_name if domain provided
if [ "$DOMAIN" != "your_domain.com" ]; then
    printf "${GREEN}[2/5] Updating server_name to ${DOMAIN}...${NC}\n"
    sed -i "s/server_name your_domain.com;/server_name ${DOMAIN};/" /etc/nginx/sites-available/n8n
else
    printf "${YELLOW}[2/5] Using default domain. Update /etc/nginx/sites-available/n8n later.${NC}\n"
fi

# Step 3: Create symbolic link to sites-enabled
printf "${GREEN}[3/5] Creating symbolic link to sites-enabled...${NC}\n"
if [ -L /etc/nginx/sites-enabled/n8n ]; then
    printf "${YELLOW}Symbolic link already exists. Removing old link...${NC}\n"
    rm /etc/nginx/sites-enabled/n8n
fi
ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Step 4: Test nginx configuration
printf "${GREEN}[4/5] Testing Nginx configuration...${NC}\n"
if nginx -t; then
    printf "${GREEN}Nginx configuration test passed!${NC}\n"
else
    printf "${RED}Nginx configuration test failed!${NC}\n"
    printf "${YELLOW}Removing invalid configuration...${NC}\n"
    rm /etc/nginx/sites-enabled/n8n
    rm /etc/nginx/sites-available/n8n
    exit 1
fi

# Step 5: Start/Restart nginx (handle both Docker and standard Alpine)
printf "${GREEN}[5/5] Starting Nginx...${NC}\n"

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
echo "  - Run certbot-install.sh to enable HTTPS"
echo ""
printf "${YELLOW}Useful commands:${NC}\n"
echo "  - Test config: nginx -t"
echo "  - Reload Nginx: nginx -s reload"
echo "  - View Nginx logs: tail -f /var/log/nginx/error.log"
echo ""
