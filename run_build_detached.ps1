# =============================================================
# PHARMA+ - Build web release en processus DETACHE
# (survit aux commandes du terminal ; ecrit le code de sortie
#  dans build_exit_code.txt a la fin du build)
# =============================================================
$ErrorActionPreference = 'Continue'
Set-Location 'c:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend'
& flutter build web --release --no-wasm-dry-run *> '..\build_web_out.txt'
$LASTEXITCODE | Set-Content -Encoding Ascii '..\build_exit_code.txt'
