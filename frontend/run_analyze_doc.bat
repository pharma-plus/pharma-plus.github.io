@echo off
cd "C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend"
dart analyze lib/features/doctors/doctor_page.dart > analyze_doc.txt 2>&1
echo Done.
timeout /t 3 /nobreak >nul