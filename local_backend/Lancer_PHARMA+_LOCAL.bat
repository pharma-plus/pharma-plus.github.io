@echo off
title PHARMA+ LOCAL - Serveur
echo ========================================
echo   PHARMA+ LOCAL - Serveur en cours
echo ========================================
echo.
echo Serveur demarre sur: http://127.0.0.1:4001
echo Base de donnees locale: pharma-local.sqlite
echo Mode: Hors-ligne (sans Internet)
echo.
echo IMPORTANT: Laissez cette fenetre ouverte.
echo Pour arreter le serveur: fermez cette fenetre ou faites Ctrl+C.
echo.

node server.js
