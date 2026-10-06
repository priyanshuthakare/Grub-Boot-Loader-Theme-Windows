<#
.SYNOPSIS
    Uninstalls Minegrub theme from Grub2Win.
#>
[CmdletBinding()]
param (
    [string]$Grub2WinPath = ""
)

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

if (-not $Grub2WinPath) {
    $Grub2WinPath = "$env:SystemDrive\grub2"
}

Write-Host "=============================================" -ForegroundColor Green
Write-Host "   Minegrub Grub2Win Uninstaller             " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

Write-Host "[*] Removing background shuffle scheduled task..." -ForegroundColor Cyan
Unregister-ScheduledTask -TaskName "MinegrubBackgroundShuffle" -Confirm:$false -ErrorAction SilentlyContinue

$themeDir = Join-Path $Grub2WinPath "themes\minegrub"
if (Test-Path $themeDir) {
    Write-Host "[*] Removing theme folder: $themeDir" -ForegroundColor Cyan
    Remove-Item -Path $themeDir -Recurse -Force -ErrorAction SilentlyContinue
}

$userThemes = Join-Path $Grub2WinPath "userfiles\user.themes"
if (Test-Path $userThemes) {
    Write-Host "[*] Cleaning up user.themes..." -ForegroundColor Cyan
    Remove-Item -Path (Join-Path $userThemes "custom.config.*") -Force -ErrorAction SilentlyContinue
}

Write-Host "[+] Minegrub theme uninstalled successfully." -ForegroundColor Green
Write-Host "[*] Open Grub2Win and click 'OK' to regenerate default theme configuration." -ForegroundColor Yellow
Read-Host "Press Enter to exit..."
