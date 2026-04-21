#!/bin/bash

# Navigate to script directory
cd "$(dirname "$0")/../macos" || exit 1

# Check for --quiet flag
QUIET=0
if [[ "$1" == "--quiet" ]]; then
    QUIET=1
fi

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

# 2. Run System Cleaner (New feature) - skip if --quiet flag
if [ $QUIET -eq 0 ]; then
    echo
    echo "Safe cleanup wrapper:"
    echo "- This script no longer deletes files directly."
    echo "- Use run/cleanup-safe.sh for dry-run and reversible moves (staging/trash)."
    echo "- Use run/audit-storage.sh for read-only storage inventory."

    read -p "Run safe cleanup dry-run now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      bash "$(dirname "$0")/cleanup-safe.sh" --dry-run --include podcasts,macwhisper,chrome,app-caches,dev-caches
    fi
fi
