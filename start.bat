@echo off
title Badminton App - Launcher
color 0A
echo ============================================
echo   BADMINTON MANAGEMENT SYSTEM - LAUNCHER
echo ============================================
echo.
echo [1/2] Dang khoi dong Backend (ASP.NET Core)...
start "Backend - ASP.NET Core" powershell -NoExit -Command "cd '%~dp0backend_caulong'; dotnet run"

timeout /t 3 /nobreak >nul

echo [2/2] Dang khoi dong Frontend (Flutter Web)...
start "Frontend - Flutter Web" cmd /k "cd /d %~dp0badminton_app_and_web && flutter run -d chrome"

echo.
echo ============================================
echo   Ca hai service da duoc khoi dong!
echo   - Backend : http://localhost:5011
echo   - Frontend: Tren trinh duyet Chrome
echo ============================================
echo.
pause
