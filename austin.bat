@echo off
REM AUSTIN - double-clickable launcher. Forwards any arguments to austin.ps1,
REM so "austin.bat -Port 7001" works the same as the PowerShell version.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0austin.ps1" %*
