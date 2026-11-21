@echo off
REM Sert la version web de TRACE sur le reseau local : ouvre l'adresse affichee sur ton telephone (meme Wi-Fi).
cd /d "%~dp0web-mobile"
echo.
echo Ouvre sur ton telephone : http://[IP-de-ce-PC]:8080   (ipconfig pour connaitre l'IP, ligne IPv4)
echo.
npx --yes serve -l 8080 .
