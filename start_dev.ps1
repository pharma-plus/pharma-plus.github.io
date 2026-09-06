# ============================================================
# PHARMA+ — Démarrage de la stack locale complète
#   1. Backend API  : http://localhost:4000  (node src/server.js)
#   2. Frontend web : http://localhost:8090  (python -m http.server)
# Chaque service n'est lancé que s'il n'écoute pas déjà.
# ============================================================

$root = 'c:\Users\Merouan\Documents\Default Project\pharma-maroc-gold'

function Test-Port($port) {
  return [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
}

# --- Backend API (port 4000) ---
if (Test-Port 4000) {
  Write-Host '[OK] Backend deja en ecoute sur http://localhost:4000' -ForegroundColor Green
} else {
  Start-Process -FilePath 'node' -ArgumentList 'src/server.js' `
    -WorkingDirectory "$root\backend" -WindowStyle Hidden `
    -RedirectStandardOutput "$root\backend\backend_log.txt" `
    -RedirectStandardError  "$root\backend\backend_err.txt"
  Write-Host '[..] Backend demarre sur http://localhost:4000 (log: backend\backend_log.txt)' -ForegroundColor Yellow
}

# --- Serveur statique frontend (port 8090) ---
if (Test-Port 8090) {
  Write-Host '[OK] Frontend deja en ecoute sur http://localhost:8090' -ForegroundColor Green
} else {
  Start-Process -FilePath 'python' -ArgumentList '-m', 'http.server', '8090', '--bind', '127.0.0.1' `
    -WorkingDirectory $root -WindowStyle Hidden `
    -RedirectStandardOutput "$root\server_log.txt" `
    -RedirectStandardError  "$root\server_err.txt"
  Write-Host '[..] Frontend demarre sur http://localhost:8090' -ForegroundColor Yellow
}

# --- Attente du backend puis verification ---
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 2
  try {
    $h = Invoke-WebRequest -Uri 'http://localhost:4000/api/v1/health' -UseBasicParsing -TimeoutSec 4
    Write-Host "[OK] Backend sain : $($h.Content)" -ForegroundColor Green
    break
  } catch { }
}

Write-Host ''
Write-Host '=> Ouvrir http://localhost:8090' -ForegroundColor Cyan
Start-Process 'http://localhost:8090'
