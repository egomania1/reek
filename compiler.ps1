# compiler.ps1 — Compile AntiCheatAIO.cs -> AntiCheatAIO.exe
# Usage: powershell -ExecutionPolicy Bypass -File "H:\SC\compiler.ps1"

$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ── Locate csc.exe (.NET Framework 4) ────────────────────────────────────
$cscCandidates = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)
$csc = $cscCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) {
    Write-Error "csc.exe introuvable. Installer .NET Framework 4."
    exit 1
}
Write-Host "csc.exe : $csc" -ForegroundColor Cyan

# ── Verify WebView2 DLLs ─────────────────────────────────────────────────
$dllCore = Join-Path $dir "Microsoft.Web.WebView2.Core.dll"
$dllWF   = Join-Path $dir "Microsoft.Web.WebView2.WinForms.dll"
if (-not (Test-Path $dllCore)) { Write-Error "Manque : $dllCore"; exit 1 }
if (-not (Test-Path $dllWF))   { Write-Error "Manque : $dllWF";   exit 1 }

# ── Compile ───────────────────────────────────────────────────────────────
$cs       = Join-Path $dir "AntiCheatAIO.cs"
$manifest = Join-Path $dir "reek.manifest"
$ico      = Join-Path $dir "reek.ico"
$out      = Join-Path $dir "Reek.exe"

$args = @(
    "/target:winexe",
    "/platform:x64",
    "/optimize+",
    "/reference:`"$dllCore`"",
    "/reference:`"$dllWF`"",
    "/reference:System.Windows.Forms.dll",
    "/reference:System.Drawing.dll",
    "/reference:System.dll",
    "/win32manifest:`"$manifest`"",
    "/win32icon:`"$ico`"",
    "/out:`"$out`"",
    "`"$cs`""
)

Write-Host "Compilation en cours..." -ForegroundColor Yellow
$result = & $csc $args 2>&1
$result | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -eq 0) {
    Remove-Item (Join-Path $dir "AntiCheatAIO.exe") -ErrorAction SilentlyContinue
    Write-Host "`nBuild OK → $out" -ForegroundColor Green
} else {
    Write-Host "`nErreur de compilation (code $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
