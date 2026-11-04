@echo off
title Installation PHARMA+ LOCAL
echo ========================================
echo   INSTALLATION PHARMA+ LOCAL
echo ========================================
echo.

echo Verification de Node.js...
node --version >nul 2>&1
if errorlevel 1 (
    echo ERREUR: Node.js n'est pas installe.
    echo.
    echo Telechargez et installez Node.js sur https://nodejs.org
    echo Puis relancez cette installation.
    echo.
    pause
    exit /b 1
)

echo.
echo Installation des dependances (patientez)...
npm install
if errorlevel 1 (
    echo.
    echo ERREUR lors de l'installation des dependances.
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   INSTALLATION TERMINEE AVEC SUCCES
echo ========================================
echo.
echo Vous pouvez maintenant double-cliquer sur :
echo   Lancer_PHARMA+_LOCAL.bat
echo.
pause
