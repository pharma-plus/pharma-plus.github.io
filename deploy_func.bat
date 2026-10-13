@echo off
cd "C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold"
npx supabase functions deploy pharma-api
timeout /t 5 /nobreak >nul