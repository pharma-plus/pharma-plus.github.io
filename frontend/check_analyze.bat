@echo off
cd "C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend"
dart analyze 2>analyze_check.txt
if %errorlevel% equ 0 (
    echo.
    echo ==========================================
    echo  SUCCESS: Dart analyze completed with no errors
    echo ==========================================
) else (
    echo.
    echo ==========================================
    echo  ANALYZE RESULTS:
    echo ==========================================
    type analyze_check.txt
)
timeout /t 5 /nobreak >nul