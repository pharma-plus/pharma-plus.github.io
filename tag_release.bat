@echo off
cd "C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold"
git tag -a v-global-final-20261008 -m "PHARMA+ final release 2026-10-08"
git push origin v-global-final-20261008
timeout /t 5 /nobreak >nul