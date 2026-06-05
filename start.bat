@echo off
title Badminton App - Launcher
color 0A
echo ============================================
echo   BADMINTON MANAGEMENT SYSTEM - LAUNCHER
echo ============================================
echo.
echo [1/2] Dang khoi dong Backend (ASP.NET Core)...
start "Backend - ASP.NET Core" powershell -NoExit -Command "cd 'd:\BTCK-LTUD\badminton\backend_caulong'; $env:MSBuildSDKsPath = 'C:\Program Files\dotnet\sdk\8.0.421\Sdks'; dotnet run"

timeout /t 3 /nobreak >nul

echo [2/2] Dang khoi dong Frontend (Flutter Web)...
start "Frontend - Flutter Web" cmd /k "cd /d d:\BTCK-LTUD\badminton\badminton_app_and_web && flutter run -d chrome"

echo.
echo ============================================
echo   Ca hai service da duoc khoi dong!
echo   - Backend : http://localhost:5000
echo   - Frontend: Tren trinh duyet Chrome
echo ============================================
echo.
pause
