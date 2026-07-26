@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Voice Occlusion Installer
echo   One-click setup from GitHub
echo ============================================
echo.

:: ============================================
::  CONFIGURATION - Set your GitHub repo info
:: ============================================
set "GITHUB_USER=Jackiepoopoo"
set "GITHUB_REPO=Immersive-Voice-Chat-"
set "RELEASE_FILE=voiceocclusion.zip"
set "DOWNLOAD_URL=https://github.com/%GITHUB_USER%/%GITHUB_REPO%/releases/latest/download/%RELEASE_FILE%"
:: ============================================

:: Detect Gmod path
set "GMOD_PATH="
for %%P in (
    "C:\Program Files (x86)\Steam"
    "C:\Program Files\Steam"
    "D:\SteamLibrary" "D:\Steam"
    "E:\SteamLibrary" "E:\Steam"
    "F:\SteamLibrary" "F:\Steam"
    "G:\SteamLibrary" "G:\Steam"
    "C:\SteamLibrary" "C:\Steam"
) do (
    if not defined GMOD_PATH (
        if exist "%%~P\steamapps\common\GarrysMod\garrysmod" (
            set "GMOD_PATH=%%~P\steamapps\common\GarrysMod"
        )
    )
)
if not defined GMOD_PATH (
    for /f "tokens=2*" %%A in ('reg query "HKCU\SOFTWARE\Valve\Steam" /v SteamPath 2^>nul') do (
        set "SP=%%B"
        set "SP=!SP:/=\!"
        if exist "!SP!\steamapps\common\GarrysMod\garrysmod" set "GMOD_PATH=!SP!\steamapps\common\GarrysMod"
    )
)
if not defined GMOD_PATH (
    echo ERROR: Could not find Garry's Mod.
    echo Please install GMod first, then run this again.
    pause
    exit /b 1
)
echo Found Garry's Mod: %GMOD_PATH%

:: Detect Mumble
set "MUMBLE_PATH="
if exist "C:\Program Files\Mumble" set "MUMBLE_PATH=C:\Program Files\Mumble"
if exist "C:\Program Files (x86)\Mumble" set "MUMBLE_PATH=C:\Program Files (x86)\Mumble"

:: Create temp directory
set "TEMP_DIR=%TEMP%\voiceocclusion_install"
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" >nul 2>&1
mkdir "%TEMP_DIR%" >nul

:: Download release zip
echo.
echo Downloading latest release...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%TEMP_DIR%\%RELEASE_FILE%' -UseBasicParsing } catch { Write-Host 'FAILED'; exit 1 }"
if not exist "%TEMP_DIR%\%RELEASE_FILE%" (
    echo ERROR: Download failed.
    echo URL: %DOWNLOAD_URL%
    echo Make sure the GitHub release exists and the URL is correct.
    pause
    exit /b 1
)
echo   Downloaded successfully.

:: Extract zip
echo Extracting...
powershell -Command "Expand-Archive -Path '%TEMP_DIR%\%RELEASE_FILE%' -DestinationPath '%TEMP_DIR%\extracted' -Force"

:: Find extracted folder (may be nested)
set "EXTRACT_DIR=%TEMP_DIR%\extracted"
if exist "%EXTRACT_DIR%\lua" (
    set "SRC=%EXTRACT_DIR%"
) else (
    for /d %%D in ("%EXTRACT_DIR%\*") do (
        if exist "%%D\lua" set "SRC=%%D"
    )
)
if not defined SRC (
    echo ERROR: Could not find addon files in the download.
    pause
    exit /b 1
)

:: Install binary module
echo.
echo Installing binary module...
if exist "%SRC%\lua\bin\gmcl_voiceocclusion_win64.dll" (
    if not exist "%GMOD_PATH%\garrysmod\lua\bin" mkdir "%GMOD_PATH%\garrysmod\lua\bin" >nul
    copy /Y "%SRC%\lua\bin\gmcl_voiceocclusion_win64.dll" "%GMOD_PATH%\garrysmod\lua\bin\gmcl_voiceocclusion_win64.dll" >nul
    echo   OK
) else (
    echo   SKIP: Binary module not in package
)

:: Install Lua addon
echo Installing addon...
set "ADDON=%GMOD_PATH%\garrysmod\addons\voiceocclusion"
mkdir "%ADDON%\lua\autorun" >nul 2>&1
mkdir "%ADDON%\lua\voiceocclusion\client" >nul 2>&1
mkdir "%ADDON%\lua\voiceocclusion\server" >nul 2>&1
mkdir "%ADDON%\materials\voiceocclusion" >nul 2>&1

copy /Y "%SRC%\lua\autorun\sh_load.lua" "%ADDON%\lua\autorun\sh_load.lua" >nul
copy /Y "%SRC%\lua\voiceocclusion\config.lua" "%ADDON%\lua\voiceocclusion\config.lua" >nul
copy /Y "%SRC%\lua\voiceocclusion\shared.lua" "%ADDON%\lua\voiceocclusion\shared.lua" >nul
copy /Y "%SRC%\lua\voiceocclusion\client\main.lua" "%ADDON%\lua\voiceocclusion\client\main.lua" >nul
copy /Y "%SRC%\lua\voiceocclusion\client\cl_module.lua" "%ADDON%\lua\voiceocclusion\client\cl_module.lua" >nul
copy /Y "%SRC%\lua\voiceocclusion\server\main.lua" "%ADDON%\lua\voiceocclusion\server\main.lua" >nul
copy /Y "%SRC%\lua\voiceocclusion\server\hooks.lua" "%ADDON%\lua\voiceocclusion\server\hooks.lua" >nul
if exist "%SRC%\materials\voiceocclusion" (
    copy /Y "%SRC%\materials\voiceocclusion\*.png" "%ADDON%\materials\voiceocclusion\" >nul
)
echo   OK

:: Install Mumble plugin
if defined MUMBLE_PATH (
    echo Installing Mumble plugin...
    if exist "%SRC%\mumble_voiceocclusion.dll" (
        if not exist "%MUMBLE_PATH%\client\plugins" mkdir "%MUMBLE_PATH%\client\plugins" >nul
        copy /Y "%SRC%\mumble_voiceocclusion.dll" "%MUMBLE_PATH%\client\plugins\mumble_voiceocclusion.dll" >nul
        echo   OK
    ) else (
        echo   SKIP: Mumble plugin not in package
    )
) else (
    echo Mumble not found - skipping plugin install
)

:: Cleanup
rd /s /q "%TEMP_DIR%" >nul 2>&1

echo.
echo ============================================
echo   Done! Restart Garry's Mod to apply.
echo.
echo   If using Mumble, also restart Mumble.
echo   Set your Mumble name = your Gmod name.
echo ============================================
pause
