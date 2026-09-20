# Build PoggyWoggy on Windows. One command, nothing to install first.
#
#     .\build.ps1            # build for this machine
#     .\build.ps1 all        # build Windows and Linux
#     .\build.ps1 run        # build if needed, then play it
#
# The engine and its export templates are downloaded once into .tooling\ inside this
# repository -- no installers, no PATH changes, nothing outside this directory.
#
# What you get: build\windows\poggywoggy.exe, a single self-contained executable.

param([string]$Mode = "host")

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$GodotVersion = (Get-Content "$Root\.godot-version").Trim()
$Tooling = Join-Path $Root ".tooling"
$GodotDir = Join-Path $Tooling "godot-$GodotVersion"
$GodotBin = Join-Path $GodotDir "godot.exe"
$TemplatesDir = Join-Path $Tooling "templates\$GodotVersion.stable"
$BaseUrl = "https://github.com/godotengine/godot/releases/download/$GodotVersion-stable"

function Info($message) { Write-Host "==> $message" -ForegroundColor Cyan }
function Fail($message) { Write-Host "error: $message" -ForegroundColor Red; exit 1 }

function Get-Engine {
    if (Test-Path $GodotBin) { return }
    New-Item -ItemType Directory -Force -Path $GodotDir | Out-Null
    $archive = Join-Path $Tooling "godot.zip"
    Info "downloading the engine"
    Invoke-WebRequest -Uri "$BaseUrl/Godot_v$GodotVersion-stable_win64.exe.zip" -OutFile $archive
    Expand-Archive -Path $archive -DestinationPath $GodotDir -Force
    Remove-Item $archive
    $extracted = Get-ChildItem -Path $GodotDir -Filter "Godot*.exe" -Recurse | Select-Object -First 1
    if (-not $extracted) { Fail "the engine archive did not contain a binary" }
    Move-Item $extracted.FullName $GodotBin -Force
    Info "engine ready"
}

function Get-Templates {
    if (Test-Path $TemplatesDir) { return }
    New-Item -ItemType Directory -Force -Path (Join-Path $Tooling "templates") | Out-Null
    $archive = Join-Path $Tooling "templates.tpz"
    Info "downloading export templates (about 1.4 GB, once)"
    Invoke-WebRequest -Uri "$BaseUrl/Godot_v$GodotVersion-stable_export_templates.tpz" -OutFile $archive
    $extract = Join-Path $Tooling "templates-extract"
    # A .tpz is a zip; PowerShell needs the extension to believe that.
    Copy-Item $archive "$archive.zip" -Force
    Expand-Archive -Path "$archive.zip" -DestinationPath $extract -Force
    Move-Item (Join-Path $extract "templates") $TemplatesDir -Force
    Remove-Item $archive, "$archive.zip", $extract -Recurse -Force
    Info "export templates ready"
}

function Link-Templates {
    # Godot looks in the user data directory; this keeps the files inside the repository.
    $userTemplates = Join-Path $env:APPDATA "Godot\export_templates"
    New-Item -ItemType Directory -Force -Path $userTemplates | Out-Null
    $target = Join-Path $userTemplates "$GodotVersion.stable"
    if (-not (Test-Path $target)) {
        try { New-Item -ItemType Junction -Path $target -Target $TemplatesDir | Out-Null }
        catch { Copy-Item $TemplatesDir $target -Recurse -Force }
    }
}

function Export-Target($preset, $output) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
    Info "exporting $preset"
    & $GodotBin --headless --path $Root --export-release $preset $output | Out-Null
    if (-not (Test-Path $output)) { Fail "$preset export produced nothing" }
    Info "built $output"
}

Get-Engine
Get-Templates
Link-Templates

Info "importing the project (first run takes a minute)"
& $GodotBin --headless --path $Root --import | Out-Null

Info "checking that the content loads"
& $GodotBin --headless --path $Root -- --smoke-test

switch ($Mode) {
    "all" {
        Export-Target "Windows Desktop" (Join-Path $Root "build\windows\poggywoggy.exe")
        Export-Target "Linux" (Join-Path $Root "build\linux\poggywoggy.x86_64")
    }
    "run" {
        $exe = Join-Path $Root "build\windows\poggywoggy.exe"
        Export-Target "Windows Desktop" $exe
        Info "starting"
        & $exe
    }
    default {
        Export-Target "Windows Desktop" (Join-Path $Root "build\windows\poggywoggy.exe")
    }
}

Info "done. Run it directly -- everything it needs is inside the file."
