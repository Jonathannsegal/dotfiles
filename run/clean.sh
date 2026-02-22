#!/bin/bash

# Navigate to script directory
cd "$(dirname "$0")/../macos" || exit 1

# 1. Run standard linting (Johnny.Decimal)
echo -n "Checking Johnny.Decimal structure... "
python3 ./jdlint.py ~/Personal \
  -i '.DS_Store' \
  -i '.tmp.drivedownload' \
  -i '.tmp.driveupload' \
  -i 'Icon*' \
  -i '**/Icon*' > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Good"
else
    echo "Issues Found"
    # Run again to show output if failed
    python3 ./jdlint.py ~/Personal \
      -i '.DS_Store' \
      -i '.tmp.drivedownload' \
      -i '.tmp.driveupload' \
      -i 'Icon*' \
      -i '**/Icon*'
fi

# 2. Run System Cleaner (New feature)
# read -p "Run System Cleaner? (y/n) " -n 1 -r
# echo
# if [[ $REPLY =~ ^[Yy]$ ]]; then
#    sudo -v
#    sudo python3 ./mac_cleaner.py
# fi

