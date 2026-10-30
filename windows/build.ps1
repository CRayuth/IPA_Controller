# Rebuild windows\dist\TouchPadFC.exe from source.
# Needs Python 3.10+ on PATH; end users never need this script.

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

python -m pip install --disable-pip-version-check --no-input vgamepad==0.2.0 pyinstaller

python -m PyInstaller --noconfirm --clean --onefile --noconsole --name TouchPadFC `
    --paths . --collect-all vgamepad --exclude-module mss --exclude-module numpy `
    --distpath windows/dist --workpath windows/build --specpath windows windows/app.py

$exe = Join-Path $root "windows\dist\TouchPadFC.exe"

if (Test-Path $exe) {
    $size = [math]::Round((Get-Item $exe).Length / 1MB, 1)
    Write-Host "Built $exe ($size MB)"
} else {
    Write-Error "Build failed"
}
