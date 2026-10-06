<#
.SYNOPSIS
    Random background shuffler for Minegrub on Windows / Grub2Win.
.DESCRIPTION
    Selects a random Minecraft background image from the backgrounds folder
    and updates background.png for the next boot.
#>

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Locate the minegrub theme directory
if (Test-Path "$scriptDir\backgrounds") {
    $themePath = $scriptDir
} else {
    $defaultCandidate = "$env:SystemDrive\grub2\themes\minegrub"
    if (Test-Path $defaultCandidate) {
        $themePath = $defaultCandidate
    } else {
        $themePath = $scriptDir
    }
}

$bgFolder = Join-Path $themePath "backgrounds"
$targetBg = Join-Path $themePath "background.png"

if (-not (Test-Path $bgFolder)) {
    Write-Host "[!] Backgrounds directory not found: $bgFolder"
    exit 1
}

$backgrounds = Get-ChildItem -LiteralPath $bgFolder -Filter "*.png" | Where-Object { -not $_.Name.StartsWith(".") }

if ($backgrounds.Count -eq 0) {
    Write-Host "[!] No background images found in $bgFolder"
    exit 1
}

$chosen = $backgrounds | Get-Random
Write-Host "[*] Selected background: $($chosen.Name)"

# Copy using -LiteralPath to correctly handle brackets [ ] in filenames
Copy-Item -LiteralPath $chosen.FullName -Destination $targetBg -Force

# Also update Grub2Win's custom background file if present
$parentTheme = Split-Path -Parent $themePath
$customBg = Join-Path $parentTheme "custom.background.png"
if (Test-Path $parentTheme) {
    Copy-Item -LiteralPath $chosen.FullName -Destination $customBg -Force
}

Write-Host "[+] Background updated successfully for next boot!"
