@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Building Distribution Package
echo ============================================
echo.

set "SRC=%~dp0"
set "OUT=%SRC%distribution\_staging"

:: Clean previous build
if exist "%SRC%distribution\_staging" rd /s /q "%SRC%distribution\_staging" >nul 2>&1
mkdir "%OUT%" >nul

:: Binary module
if exist "%SRC%cpp\build\Release\gmcl_immersivevoicechat.dll" (
    copy /Y "%SRC%cpp\build\Release\gmcl_immersivevoicechat.dll" "%OUT%\gmcl_immersivevoicechat_win64.dll" >nul
    echo   OK: Binary module
) else (
    echo   SKIP: Binary module not built
)

:: Mumble plugin
if exist "%SRC%mumble\build\Release\mumble_immersivevoicechat.dll" (
    copy /Y "%SRC%mumble\build\Release\mumble_immersivevoicechat.dll" "%OUT%\mumble_immersivevoicechat.dll" >nul
    echo   OK: Mumble plugin
) else (
    echo   SKIP: Mumble plugin not built
)

:: Copy installer
copy /Y "%SRC%distribute_install.bat" "%OUT%\install.bat" >nul

:: Create zip
powershell -command "Compress-Archive -Path '%OUT%\*' -DestinationPath '%SRC%distribution\immersivevoicechat.zip' -Force"
echo   OK: Created immersivevoicechat.zip

:: Cleanup staging folder
rd /s /q "%OUT%" >nul 2>&1

echo.
echo ============================================
echo   Distribution package ready!
echo   Location: distribution\immersivevoicechat.zip
echo.
echo   Share this zip with your friends.
echo   They just extract and run install.bat.
echo ============================================
pause
