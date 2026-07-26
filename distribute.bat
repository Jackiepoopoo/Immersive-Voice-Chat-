@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Building Distribution Package
echo ============================================
echo.

set "SRC=%~dp0"
set "OUT=%SRC%distribution"

:: Clean previous build
if exist "%OUT%" rd /s /q "%OUT%" >nul 2>&1
mkdir "%OUT%" >nul

:: Binary module
if exist "%SRC%cpp\build\Release\gmcl_voiceocclusion.dll" (
    copy /Y "%SRC%cpp\build\Release\gmcl_voiceocclusion.dll" "%OUT%\gmcl_voiceocclusion_win64.dll" >nul
    echo   OK: Binary module
) else (
    echo   SKIP: Binary module not built
)

:: Mumble plugin
if exist "%SRC%mumble\build\Release\mumble_voiceocclusion.dll" (
    copy /Y "%SRC%mumble\build\Release\mumble_voiceocclusion.dll" "%OUT%\mumble_voiceocclusion.dll" >nul
    echo   OK: Mumble plugin
) else (
    echo   SKIP: Mumble plugin not built
)

:: Copy installer
copy /Y "%SRC%distribute_install.bat" "%OUT%\install.bat" >nul

:: Create zip in parent directory, then clean up temp folder
powershell -command "Compress-Archive -Path '%OUT%\*' -DestinationPath '%SRC%distribution\voiceocclusion.zip' -Force"
echo   OK: Created voiceocclusion.zip

:: Cleanup temp folder
rd /s /q "%OUT%" >nul 2>&1

echo.
echo ============================================
echo   Distribution package ready!
echo   Location: distribution\voiceocclusion.zip
echo.
echo   Share this zip with your friends.
echo   They just extract and run install.bat.
echo ============================================
pause
