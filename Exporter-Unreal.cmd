@echo off
rem TRACE - export du quartier vers Unreal (.glb). Double-clique, attends le message "terminé".
cd /d "%~dp0"
"%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." -s res://.tools/export_unreal.gd
echo.
if exist "%~dp0export_unreal\quartier_2013.glb" (echo Fichier cree : export_unreal\quartier_2013.glb) else (echo ECHEC : pas de fichier. Envoie une capture de cette fenetre a Claude.)
pause
