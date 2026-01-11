#!/bin/bash
# Filtered logcat with raw format - shows only our [LOG] messages
adb logcat -v raw | grep --line-buffered "\[LOG"
