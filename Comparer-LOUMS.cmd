@echo off
cd /d "%~dp0"
"%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://scenes/loums_comparison.tscn
