<#
Build script for FS25_EmployeeManager

Steps:
1) Select files/folders (gui, language/translations, scripts, icon, modDesc.xml, register.lua)
2) Create ZIP archive using 7-Zip (preferred) or Compress-Archive as fallback
3) Move/replace archive into Farming Simulator mods folder

Usage: run from repository root (double-click or powershell):
    .\build.ps1
#>

param(
    [string]$SevenZipPath = 'C:\Program Files\7-Zip\7z.exe',
    [string]$ModName = 'FS25_EmployeeManager',
    [string]$ModsDest = 'C:\Users\xalsi\Documents\My Games\FarmingSimulator2025\mods'
)

Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "Building mod from: $root"

$candidates = @('images','l10n','scripts','modDesc.xml', 'xml')
$items = @()
foreach($c in $candidates){
    $p = Join-Path $root $c
    if(Test-Path $p){ $items += $c }
}

if($items.Count -eq 0){
    Write-Error "No files or folders found to include. Check your repository layout."
    exit 1
}

$zipName = "$ModName.zip"
$zipPath = Join-Path $root $zipName

if(Test-Path $zipPath){
    Remove-Item $zipPath -Force
}

Push-Location $root
try{
    if(Test-Path $SevenZipPath){
        $args = @('a','-tzip',$zipPath) + $items
        Write-Host "Using 7-Zip: $SevenZipPath -> $zipPath"
        & $SevenZipPath @args | Out-Null
        if($LASTEXITCODE -ne 0){ throw "7-Zip failed with exit code $LASTEXITCODE" }
    } else {
        Write-Host "7-Zip not found at '$SevenZipPath'. Using Compress-Archive fallback."
        $fullPaths = $items | ForEach-Object { Join-Path $root $_ }
        Compress-Archive -Path $fullPaths -DestinationPath $zipPath -Force
    }
    Write-Host "Archive created: $zipPath"

    if(-not (Test-Path $ModsDest)){
        Write-Host "Mods destination folder does not exist. Creating: $ModsDest"
        New-Item -ItemType Directory -Path $ModsDest -Force | Out-Null
    }

    $destPath = Join-Path $ModsDest $zipName
    if(Test-Path $destPath){ Remove-Item $destPath -Force }
    Copy-Item -Path $zipPath -Destination $destPath -Force
    Write-Host "Copied archive to mods folder: $destPath"
    Remove-Item $zipPath -Force
}
catch{
    Write-Error "Build failed: $_"
    Pop-Location
    exit 2
}
finally{
    Pop-Location
}

Write-Host "Build complete."
