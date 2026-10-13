@echo off
cd "C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend"
dart analyze 2>analyze_current.txt
type analyze_current.txt
timeout /t 5 /nobreak >nul