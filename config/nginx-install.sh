#!/bin/bash

# Nginx Configuration Install Script for n8n
# Usage: sudo ./nginx-install.sh

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/n8n.conf"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Nginx Configuration Install Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if n8n.conf exists
if [ ! -f "$CONF_FILE" ]; then
    echo -e "${RED}Error: n8n.conf not found in ${SCRIPT_DIR}${NC}"
    exit 1
fi

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo -e "${YELLOW}Nginx is not installed. Installing...${NC}"
    apt update
    apt install nginx -y
fi

# Step 1: Copy config file to sites-available
echo -e "${GREEN}[1/4] Copying n8n.conf to /etc/nginx/sites-available/...${NC}"
cp "$CONF_FILE" /etc/nginx/sites-available/n8n

# Step 2: Create symbolic link to sites-enabled
echo -e "${GREEN}[2/4] Creating symbolic link to sites-enabled...${NC}"
if [ -L /etc/nginx/sites-enabled/n8n ]; then
    echo -e "${YELLOW}Symbolic link already exists. Removing old link...${NC}"
    rm /etc/nginx/sites-enabled/n8n
fi
ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Step 3: Test nginx configuration
echo -e "${GREEN}[3/4] Testing Nginx configuration...${NC}"
if nginx -t; then
    echo -e "${GREEN}Nginx configuration test passed!${NC}"
else
    echo -e "${RED}Nginx configuration test failed!${NC}"
    echo -e "${YELLOW}Removing invalid configuration...${NC}"
    rm /etc/nginx/sites-enabled/n8n
    rm /etc/nginx/sites-available/n8n
    exit 1
fi

# Step 4: Restart nginx
echo -e "${GREEN}[4/4] Restarting Nginx...${NC}"
systemctl restart nginx

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Configuration file: ${YELLOW}/etc/nginx/sites-available/n8n${NC}"
echo -e "Symbolic link: ${YELLOW}/etc/nginx/sites-enabled/n8n${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Update 'server_name' in /etc/nginx/sites-available/n8n"
echo "  2. Run certbot-install.sh to enable HTTPS"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  - Check Nginx status: sudo systemctl status nginx"
echo "  - Reload Nginx: sudo systemctl reload nginx"
echo "  - View Nginx logs: sudo tail -f /var/log/nginx/error.log"
echo ""
