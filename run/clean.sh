#!/bin/bash

cd "$(dirname "$0")/../macos" || exit 1
python3 ./jdlint.py ~/Personal \
  -i '.DS_Store' \
  -i '.tmp.drivedownload' \
  -i '.tmp.driveupload' \
  -i 'Icon*' \
  -i '**/Icon*'
