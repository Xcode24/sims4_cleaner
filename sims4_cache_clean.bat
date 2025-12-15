@echo off
chcp 65001 > nul

set "URL=https://raw.githubusercontent.com/Xcode24/sims4_cleaner/refs/heads/main/sims4_cache_clean.ps1"
set "PSFILE=%TEMP%\sims4_cache_clean.ps1"

powershell -NoProfile -ExecutionPolicy Bypass ^
  -Command "Invoke-WebRequest -Uri '%URL%' -OutFile '%PSFILE%'"

powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%PSFILE%"