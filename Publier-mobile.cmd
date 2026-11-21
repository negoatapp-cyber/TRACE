@echo off
REM 1) Re-exporte le jeu en version web (avec le son), 2) publie sur Vercel. Donne un lien a ouvrir sur le telephone.
cd /d "%~dp0"
set "TPL=%APPDATA%\Godot\export_templates\4.7.2.stable"
if not exist "%TPL%\web_nothreads_release.zip" (
  mkdir "%TPL%" 2>nul
  copy /y "%~dp0.tools\export_templates\4.7.2.stable\*" "%TPL%\" >nul
)
"%~dp0.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." --export-release "Web" "web-mobile/index.html"
if errorlevel 1 (
  echo Export Godot en echec. Publication annulee.
  exit /b 1
)
cd /d "%~dp0web-mobile"
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; $html=Get-Content -LiteralPath index.html -Raw; $json=[regex]::Match($html,'(?m)^const GODOT_CONFIG = (.+);').Groups[1].Value; $config=ConvertFrom-Json -InputObject $json; foreach($name in @('index.pck','index.wasm')) { $size=$config.fileSizes.$name; if ($size -le 0 -or (Get-Item -LiteralPath $name).Length -ne $size) { throw ('Export incomplet : '+$name) } }"
if errorlevel 1 exit /b 1
npx --yes vercel deploy --prod
