# =============================================================
# PHARMA+ - Deploiement du build web Flutter vers la racine
# Usage :  powershell -ExecutionPolicy Bypass -File .\deploy_web.ps1
# Prerequis : flutter build web --release  (dans frontend\)
# Copie frontend\build\web vers la racine SANS rien supprimer.
# =============================================================

$root = 'c:\Users\Merouan\Documents\Default Project\pharma-maroc-gold'
$src  = Join-Path $root 'frontend\build\web'

if (-not (Test-Path (Join-Path $src 'main.dart.js'))) {
  Write-Error "Build introuvable dans $src - lancez d'abord : flutter build web --release"
  exit 1
}

$files = @('main.dart.js','index.html','flutter_bootstrap.js','flutter_service_worker.js','flutter.js','manifest.json','version.json','favicon.png','favicon.svg')
foreach ($f in $files) {
  $p = Join-Path $src $f
  if (Test-Path $p) { Copy-Item -Path $p -Destination $root -Force }
}

foreach ($dir in @('assets','canvaskit','icons')) {
  $from = Join-Path $src $dir
  if (Test-Path $from) {
    Copy-Item -Path $from -Destination $root -Recurse -Force
  }
}

Write-Host 'Deploiement web termine.' -ForegroundColor Green

# =============================================================
# ANTI-CACHE DEFINITIF : nom de build unique.
# Chaque deploiement cree main.<stamp>.dart.js et patche
# flutter_bootstrap.js pour pointer dessus. Le navigateur ne
# peut JAMAIS servir ce fichier depuis son cache (URL inedite).
# =============================================================
$stamp = Get-Date -Format 'yyyyMMddHHmm'
Copy-Item -Path (Join-Path $src 'main.dart.js') -Destination (Join-Path $root ("main.$stamp.dart.js")) -Force

$boot = Join-Path $root 'flutter_bootstrap.js'
$bootTxt = [System.IO.File]::ReadAllText($boot)
$bootTxt = $bootTxt.Replace('"mainJsPath":"main.dart.js"', ('"mainJsPath":"main.' + $stamp + '.dart.js"'))
[System.IO.File]::WriteAllText($boot, $bootTxt, (New-Object System.Text.UTF8Encoding($false)))

$idx = Join-Path $root 'index.html'
$idxTxt = [System.IO.File]::ReadAllText($idx)
$idxTxt = [System.Text.RegularExpressions.Regex]::Replace($idxTxt, 'flutter_bootstrap\.js\?v=[0-9a-zA-Z]+', ('flutter_bootstrap.js?v=' + $stamp))
[System.IO.File]::WriteAllText($idx, $idxTxt, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ("Anti-cache actif : main." + $stamp + ".dart.js") -ForegroundColor Green
Get-Item (Join-Path $root 'main.dart.js') | Select-Object Name, Length, LastWriteTime

