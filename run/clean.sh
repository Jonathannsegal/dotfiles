#!/bin/bash

# Navigate to script directory
cd "$(dirname "$0")/../macos" || exit 1

# 1. Run standard linting (Johnny.Decimal)
echo "----------------------------------------------------------------"
echo "Running Johnny.Decimal Linter..."
python3 ./jdlint.py ~/Personal \
  -i '.DS_Store' \
  -i '.tmp.drivedownload' \
  -i '.tmp.driveupload' \
  -i 'Icon*' \
  -i '**/Icon*'

# 2. Run System Cleaner (New feature)
echo "----------------------------------------------------------------"
echo "Running System Cleaner (Apps, Leftovers, Large Files)..."
# Check if sudo is needed (mac_cleaner.py checks internally but better to ask here)
# Use 'sudo -v' to update timestamp without running command if needed, or just run python with sudo
sudo -v
sudo python3 ./mac_cleaner.py

