@echo off
REM Lance la rue pilote (impasse de la Paix) seule, avec Loums. Le jeu complet reste Jouer-TRACE.cmd.
"%~dp0.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." --import >nul 2>&1
start "TRACE - rue pilote" "%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://scenes/rue_paix.tscn
