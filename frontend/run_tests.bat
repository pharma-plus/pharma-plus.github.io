@echo off
cd "C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend"
flutter test 2>test_current.txt
echo.
echo Test completed.
timeout /t 5 /nobreak >nul