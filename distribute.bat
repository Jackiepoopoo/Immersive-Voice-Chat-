@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Building Distribution Package
echo ============================================
echo.

set "SRC=%~dp0"
set "OUT=%SRC%distribution\voiceocclusion"

:: Clean previous build
if exist "%SRC%distribution" rd /s /q "%SRC%distribution" >nul 2>&1
mkdir "%OUT%" >nul

:: Lua addon files
mkdir "%OUT%\lua\autorun" >nul
mkdir "%OUT%\lua\bin" >nul
mkdir "%OUT%\lua\voiceocclusion\client" >nul
mkdir "%OUT%\lua\voiceocclusion\server" >nul
mkdir "%OUT%\materials\voiceocclusion" >nul

copy /Y "%SRC%lua\autorun\sh_load.lua" "%OUT%\lua\autorun\sh_load.lua" >nul
copy /Y "%SRC%lua\voiceocclusion\config.lua" "%OUT%\lua\voiceocclusion\config.lua" >nul
copy /Y "%SRC%lua\voiceocclusion\shared.lua" "%OUT%\lua\voiceocclusion\shared.lua" >nul
copy /Y "%SRC%lua\voiceocclusion\client\main.lua" "%OUT%\lua\voiceocclusion\client\main.lua" >nul
copy /Y "%SRC%lua\voiceocclusion\client\cl_module.lua" "%OUT%\lua\voiceocclusion\client\cl_module.lua" >nul
copy /Y "%SRC%lua\voiceocclusion\server\main.lua" "%OUT%\lua\voiceocclusion\server\main.lua" >nul
copy /Y "%SRC%lua\voiceocclusion\server\hooks.lua" "%OUT%\lua\voiceocclusion\server\hooks.lua" >nul

:: Materials
copy /Y "%SRC%materials\voiceocclusion\*.png" "%OUT%\materials\voiceocclusion\" >nul

:: Binary module
if exist "%SRC%cpp\build\Release\gmcl_voiceocclusion.dll" (
    copy /Y "%SRC%cpp\build\Release\gmcl_voiceocclusion.dll" "%OUT%\lua\bin\gmcl_voiceocclusion_win64.dll" >nul
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

:: Copy install.bat
copy /Y "%SRC%distribute_install.bat" "%OUT%\install.bat" >nul

:: Create zip
powershell -command "Compress-Archive -Path '%OUT%\*' -DestinationPath '%SRC%distribution\voiceocclusion.zip' -Force"
echo   OK: Created voiceocclusion.zip

:: Cleanup temp folder
rd /s /q "%SRC%distribution\voiceocclusion" >nul 2>&1

echo.
echo ============================================
echo   Distribution package ready!
echo   Location: distribution\voiceocclusion.zip
echo.
echo   Share this zip with your friends.
echo   They just extract and run install.bat.
echo ============================================
pause
