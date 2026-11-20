@echo off
setlocal
cd /d "%~dp0"
set "TRACE_GODOT=.tools\godot\Godot_v4.7.2-stable_win64.exe"
if exist "%TRACE_GODOT%" goto launch
set "TRACE_GODOT=godot"
where godot >nul 2>nul
if not errorlevel 1 goto launch
echo Installez Godot 4.7.2 et ouvrez project.godot, puis appuyez sur F5.
pause
exit /b 1
:launch
"%TRACE_GODOT%" --headless --editor --import --path .
if errorlevel 1 exit /b 1
start "TRACE" "%TRACE_GODOT%" --path .
