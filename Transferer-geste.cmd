@echo off
chcp 65001 >nul
cd /d "%~dp0"
rem TRACE : transfere une capture de mouvement (Rokoko, Uthana, Move...) sur Loums.
rem Glisse le fichier .fbx (ou .glb) de la capture sur ce fichier.
if "%~1"=="" (
  echo Glisse le fichier .fbx de ta capture sur Transferer-geste.cmd.
  pause
  exit /b
)
echo.
echo Capture : %~nx1
echo.
echo Quel geste remplace-t-elle ?
echo   attente   marche   course   saut   reception   hisser   enjamber   pendu
echo.
set /p NOM=Geste : 
".tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s .tools/retarget_loums.gd -- "%~1" %NOM%
echo.
echo Si tu vois "OK", relance le jeu : Loums fait ton geste.
pause
