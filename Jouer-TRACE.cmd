@echo off
REM Met a jour l index des scripts (nouvelles classes, nouveaux fichiers), puis lance le jeu.
"%~dp0.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." --import >nul 2>&1
start "TRACE" "%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
