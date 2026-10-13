@echo off
cd "C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend"
dart analyze 2>analyze_all.txt
echo Done.
timeout /t 5 /nobreak >nul