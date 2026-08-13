@echo off
echo ==============================================
echo   PHARMA MAROC GOLD - Demarrage complet
echo ==============================================
echo.

echo [1/4] Demarrage de PostgreSQL 18...
"C:\Program Files\PostgreSQL\18\bin\pg_ctl.exe" start -D "C:\Program Files\PostgreSQL\18\data" -l "C:\Users\Merouan\AppData\Local\Temp\opencode\pglog6.txt" -w

echo [2/4] Attente de la base (jusqu'a 3 min au premier demarrage)...
set /a tries=0
:WAITDB
"C:\Program Files\PostgreSQL\18\bin\psql.exe" "postgresql://pmg:pmg_pass_2026@localhost:5432/pharma_maroc_gold" -c "SELECT 1;" >nul 2>&1
if errorlevel 1 (
  set /a tries+=1
  if %tries% gtr 36 (
    echo      ERREUR : base non disponible apres 3 min.
    echo      Si PostgreSQL tourne deja mais ne repond pas, redemarrez
    echo      la machine puis relancez ce script.
    goto :EOF
  )
  ping -n 6 127.0.0.1 >nul
  goto WAITDB
)
echo      Base prete.

echo [3/4] Arret des anciens services (si presents)...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":4000" ^| findstr "LISTENING"') do taskkill /F /PID %%a >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5000" ^| findstr "LISTENING"') do taskkill /F /PID %%a >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8080" ^| findstr "LISTENING"') do taskkill /F /PID %%a >nul 2>&1

echo [4/4] Demarrage de l'API (4000), du portal (5000) et de l'app (8080)...
start "PMG API" /min /d "C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\backend" cmd /c "node src/server.js 1>C:\Users\Merouan\AppData\Local\Temp\opencode\pmg-out5.log 2>C:\Users\Merouan\AppData\Local\Temp\opencode\pmg-err5.log"
start "PMG Portal" /min cmd /c "node C:\Users\Merouan\AppData\Local\Temp\opencode\portal-server.js 1>C:\Users\Merouan\AppData\Local\Temp\opencode\portal-out4.log 2>C:\Users\Merouan\AppData\Local\Temp\opencode\portal-err4.log"
start "PMG Flutter" /min cmd /c "node C:\Users\Merouan\AppData\Local\Temp\opencode\flutter-web-server.js 1>C:\Users\Merouan\AppData\Local\Temp\opencode\fw-out4.log 2>C:\Users\Merouan\AppData\Local\Temp\opencode\fw-err4.log"

echo      Attente de l'API...
set /a tries=0
:WAITAPI
netstat -ano | findstr ":4000" | findstr "LISTENING" >nul
if errorlevel 1 (
  set /a tries+=1
  if %tries% gtr 20 (
    echo      ERREUR : API non demarree. Consultez pmg-err5.log
    goto :EOF
  )
  ping -n 4 127.0.0.1 >nul
  goto WAITAPI
)

echo.
echo ==============================================
echo   Tout est demarre !
echo   App web    : http://localhost:8080
echo   Portal     : http://localhost:5000
echo   API        : http://localhost:4000
echo ==============================================
ping -n 3 127.0.0.1 >nul
start "" "http://localhost:8080"
