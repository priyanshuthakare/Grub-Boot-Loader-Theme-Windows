@echo off
title Choose Minegrub Background
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0choose_background.ps1"
pause
