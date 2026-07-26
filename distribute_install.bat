@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Voice Occlusion Installer
echo ============================================
echo.

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

:: Check registry for custom Steam location
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

set "INSTALL_DIR=%~dp0"

:: Install binary module
echo.
echo Installing binary module...
if exist "%INSTALL_DIR%lua\bin\gmcl_voiceocclusion_win64.dll" (
    if not exist "%GMOD_PATH%\garrysmod\lua\bin" mkdir "%GMOD_PATH%\garrysmod\lua\bin" >nul
    copy /Y "%INSTALL_DIR%lua\bin\gmcl_voiceocclusion_win64.dll" "%GMOD_PATH%\garrysmod\lua\bin\gmcl_voiceocclusion_win64.dll" >nul
    echo   OK
) else (
    echo   SKIP: Binary module not found in package
)

:: Install Lua addon + materials
echo Installing addon...
set "ADDON=%GMOD_PATH%\garrysmod\addons\voiceocclusion"
mkdir "%ADDON%\lua\autorun" >nul 2>&1
mkdir "%ADDON%\lua\voiceocclusion\client" >nul 2>&1
mkdir "%ADDON%\lua\voiceocclusion\server" >nul 2>&1
mkdir "%ADDON%\materials\voiceocclusion" >nul 2>&1

copy /Y "%INSTALL_DIR%lua\autorun\sh_load.lua" "%ADDON%\lua\autorun\sh_load.lua" >nul
copy /Y "%INSTALL_DIR%lua\voiceocclusion\config.lua" "%ADDON%\lua\voiceocclusion\config.lua" >nul
copy /Y "%INSTALL_DIR%lua\voiceocclusion\shared.lua" "%ADDON%\lua\voiceocclusion\shared.lua" >nul
copy /Y "%INSTALL_DIR%lua\voiceocclusion\client\main.lua" "%ADDON%\lua\voiceocclusion\client\main.lua" >nul
copy /Y "%INSTALL_DIR%lua\voiceocclusion\client\cl_module.lua" "%ADDON%\lua\voiceocclusion\client\cl_module.lua" >nul
copy /Y "%INSTALL_DIR%lua\voiceocclusion\server\main.lua" "%ADDON%\lua\voiceocclusion\server\main.lua" >nul
copy /Y "%INSTALL_DIR%lua\voiceocclusion\server\hooks.lua" "%ADDON%\lua\voiceocclusion\server\hooks.lua" >nul
copy /Y "%INSTALL_DIR%materials\voiceocclusion\*.png" "%ADDON%\materials\voiceocclusion\" >nul
echo   OK

:: Install Mumble plugin
if defined MUMBLE_PATH (
    echo Installing Mumble plugin...
    if exist "%INSTALL_DIR%mumble_voiceocclusion.dll" (
        if not exist "%MUMBLE_PATH%\client\plugins" mkdir "%MUMBLE_PATH%\client\plugins" >nul
        copy /Y "%INSTALL_DIR%mumble_voiceocclusion.dll" "%MUMBLE_PATH%\client\plugins\mumble_voiceocclusion.dll" >nul
        echo   OK
    ) else (
        echo   SKIP: Mumble plugin not found in package
    )
) else (
    echo Mumble not found - skipping plugin install
)

echo.
echo ============================================
echo   Done! Restart Garry's Mod to apply.
echo.
echo   If using Mumble, also restart Mumble.
echo   Set your Mumble name to match your
echo   Garry's Mod name for voice to work.
echo ============================================
pause
