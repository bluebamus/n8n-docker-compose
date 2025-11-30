#!/bin/bash

# ===========================================
# N8N Docker Compose Initialization Script
# ===========================================
#
# Description:
#   This script removes all .gitkeep files from the storage directory.
#   .gitkeep files are placeholder files used to track empty directories
#   in Git. After cloning the repository, these files are no longer needed
#   and can be safely removed before running Docker Compose.
#
# Usage:
#   1. Make the script executable (first time only):
#      chmod +x init-script.sh
#
#   2. Run the script:
#      ./init-script.sh
#
#   Or run directly with bash:
#      bash init-script.sh
#
# What this script does:
#   1. Determines the script's directory location
#   2. Searches for all .gitkeep files under the 'storage' folder
#   3. Lists found .gitkeep files (if any)
#   4. Deletes all found .gitkeep files
#
# ===========================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORAGE_DIR="$SCRIPT_DIR/storage"

# -------------------------------------------
# Remove .gitkeep files from storage folder
# -------------------------------------------
echo "Searching for .gitkeep files in $STORAGE_DIR ..."

# Find all .gitkeep files in storage directory
gitkeep_files=$(find "$STORAGE_DIR" -name ".gitkeep" -type f 2>/dev/null)

if [ -z "$gitkeep_files" ]; then
    echo "No .gitkeep files found."
else
    echo "Found .gitkeep files:"
    echo "$gitkeep_files"
    echo ""
    echo "Deleting .gitkeep files..."
    find "$STORAGE_DIR" -name ".gitkeep" -type f -delete
    echo "All .gitkeep files have been deleted."
fi
