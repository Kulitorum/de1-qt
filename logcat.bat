@echo off
REM Filtered logcat with raw format - shows only our [LOG] messages
adb logcat -v raw | findstr "[LOG"
