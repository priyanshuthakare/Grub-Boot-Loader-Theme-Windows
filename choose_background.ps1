<#
.SYNOPSIS
    Interactive background selector for Windows / Grub2Win.
#>
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bgDir = Join-Path $scriptDir "background_options"

if (-not (Test-Path $bgDir)) {
    $bgDir = Join-Path $scriptDir "minegrub\backgrounds"
}

if (-not (Test-Path $bgDir)) {
    Write-Error "Could not find background_options directory."
    exit 1
}

$backgrounds = Get-ChildItem -Path $bgDir -Filter "*.png" | Where-Object { -not $_.Name.StartsWith(".") } | Sort-Object Name

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "   Choose a Minegrub Background              " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

for ($i = 0; $i -lt $backgrounds.Count; $i++) {
    Write-Host "  [$i] $($backgrounds[$i].BaseName)"
}

Write-Host ""
$choice = Read-Host "Enter the number of the background you want (or press Enter to cancel)"

if ($choice -match '^\d+$' -and [int]$choice -ge 0 -and [int]$choice -lt $backgrounds.Count) {
    $selected = $backgrounds[[int]$choice]
    Write-Host "[*] Selected: $($selected.Name)" -ForegroundColor Cyan

    # Copy to repo minegrub/background.png
    $repoBg = Join-Path $scriptDir "minegrub\background.png"
    if (Test-Path (Split-Path $repoBg)) {
        Copy-Item -LiteralPath $selected.FullName -Destination $repoBg -Force
    }

    # If installed in Grub2Win, update there as well
    $grub2Theme = "$env:SystemDrive\grub2\themes\minegrub"
    if (Test-Path $grub2Theme) {
        Copy-Item -LiteralPath $selected.FullName -Destination "$grub2Theme\background.png" -Force
        Copy-Item -LiteralPath $selected.FullName -Destination "$env:SystemDrive\grub2\themes\custom.background.png" -Force
        Write-Host "[+] Applied to Grub2Win installation as well!" -ForegroundColor Green
    }

    Write-Host "[+] Background updated successfully!" -ForegroundColor Green
} else {
    Write-Host "[-] Cancelled. Background was not changed." -ForegroundColor Yellow
}
