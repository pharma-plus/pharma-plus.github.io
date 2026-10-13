@echo off
cd "C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend"
dart analyze 2>analyze_current.txt
echo.
echo ==========================================
echo  DART ANALYZE RESULTS
echo ==========================================
type analyze_current.txt
echo.
findstr /i "error\|warning\|info" analyze_current.txt | find /v "" > summary.txt
type summary.txt
timeout /t 3 /nobreak >nul