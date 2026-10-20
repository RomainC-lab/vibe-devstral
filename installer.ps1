# Installe Mistral Vibe (pip) et copie la configuration Devstral dans ~\.vibe\
# PowerShell :
#   powershell -ExecutionPolicy Bypass -File .\installer.ps1            (n'ecrase rien)
#   powershell -ExecutionPolicy Bypass -File .\installer.ps1 -Force     (remplace, apres sauvegarde)
#   powershell -ExecutionPolicy Bypass -File .\installer.ps1 -SansPip   (copie seulement les fichiers)
param(
    [switch]$Force,
    [switch]$SansPip
)
$ErrorActionPreference = "Stop"

$Ici = $PSScriptRoot
$Source = Join-Path $Ici "vibe"
if ($env:VIBE_HOME) { $Dest = $env:VIBE_HOME } else { $Dest = Join-Path $HOME ".vibe" }

# 1. Mistral Vibe
if (-not $SansPip) {
    if (Get-Command py -ErrorAction SilentlyContinue) { $Py = @("py", "-3") }
    else { $Py = @("python") }
    $PyExe = $Py[0]
    $PyArgs = @($Py | Select-Object -Skip 1)
    Write-Host "== Installation de mistral-vibe avec $($Py -join ' ') -m pip"
    & $PyExe @PyArgs -m pip install --upgrade mistral-vibe
    if ($LASTEXITCODE -ne 0) {
        & $PyExe @PyArgs -m pip install --user --upgrade mistral-vibe
        if ($LASTEXITCODE -ne 0) { throw "pip install a echoue." }
    }
    if (-not (Get-Command vibe -ErrorAction SilentlyContinue)) {
        Write-Host "!! La commande 'vibe' n'est pas encore dans le PATH." -ForegroundColor Yellow
        Write-Host "   Ajoute ce dossier au PATH Windows puis rouvre le terminal :"
        & $PyExe @PyArgs -c "import sysconfig, os; print('   ' + sysconfig.get_path('scripts')); print('   ' + sysconfig.get_path('scripts', os.name + '_user'))"
    }
}

# 2. Fichiers de configuration
Write-Host "== Copie de la configuration vers $Dest"
$Sauvegarde = Join-Path $Dest ("sauvegarde-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$Gardes = @()
Get-ChildItem -Path $Source -Recurse -File -Force | ForEach-Object {
    $Rel = $_.FullName.Substring($Source.Length).TrimStart('\', '/')
    $Cible = Join-Path $Dest $Rel
    New-Item -ItemType Directory -Force -Path (Split-Path $Cible) | Out-Null
    if (-not (Test-Path $Cible)) {
        Copy-Item $_.FullName $Cible
        Write-Host "   ajoute      $Rel"
    }
    elseif ((Get-FileHash $_.FullName).Hash -eq (Get-FileHash $Cible).Hash) {
        Write-Host "   identique   $Rel"
    }
    elseif ($Force) {
        $Copie = Join-Path $Sauvegarde $Rel
        New-Item -ItemType Directory -Force -Path (Split-Path $Copie) | Out-Null
        Copy-Item $Cible $Copie
        Copy-Item $_.FullName $Cible -Force
        Write-Host "   remplace    $Rel (ancien dans $Sauvegarde)"
    }
    else {
        $script:Gardes += $Rel
        Write-Host "   GARDE       $Rel (le tien est different)" -ForegroundColor Yellow
    }
}

# 3. Fichier des cles (seulement s'il n'existe pas)
$FichierCles = Join-Path $Dest ".env"
if (-not (Test-Path $FichierCles)) {
    Copy-Item (Join-Path $Ici "vibe-env.exemple") $FichierCles
    Write-Host "   cree        .env (a remplir avec ta cle)"
}

if ($Gardes.Count -gt 0) {
    Write-Host ""
    Write-Host "Fichiers gardes tels quels : $($Gardes -join ', ')"
    Write-Host "Pour les remplacer (avec sauvegarde) : .\installer.ps1 -Force"
}
Write-Host ""
Write-Host "Fini. Mets ta cle dans $FichierCles puis lance 'vibe' dans un projet."
