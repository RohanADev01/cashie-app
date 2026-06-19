#!/bin/bash
# Usage: ./snap.sh <out_name> <startAt> [extra args]
NAME="$1"; SCREEN="$2"; shift 2
xcrun simctl terminate "iPhone 15 Pro" com.cashie.app 2>/dev/null
sleep 0.4
xcrun simctl launch "iPhone 15 Pro" com.cashie.app -startAt "$SCREEN" "$@" >/dev/null
sleep 1.6
xcrun simctl io "iPhone 15 Pro" screenshot "/Users/crabchilli/Documents/cashly/screenshots/app/${NAME}.png" >/dev/null 2>&1
echo "captured $NAME @ $SCREEN"
