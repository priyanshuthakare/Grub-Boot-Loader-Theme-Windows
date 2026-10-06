<#
.SYNOPSIS
    Automated installer for Minegrub theme in Grub2Win (Windows).
.DESCRIPTION
    Installs the Minecraft GRUB theme into Grub2Win, copies fonts,
    adjusts boot option alignment, patches Grub2Win templates for persistence,
    and optionally sets up an automatic background shuffle task on user logon.
#>
[CmdletBinding()]
param (
    [string]$Grub2WinPath = "",
    [int]$BootOptionsCount = 0,
    [switch]$NoShuffle,
    [switch]$Quiet
)

# 1. Require Administrator elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[*] Requesting Administrator privileges..." -ForegroundColor Cyan
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Grub2WinPath) { $arguments += " -Grub2WinPath `"$Grub2WinPath`"" }
    if ($BootOptionsCount -gt 0) { $arguments += " -BootOptionsCount $BootOptionsCount" }
    if ($NoShuffle) { $arguments += " -NoShuffle" }
    if ($Quiet) { $arguments += " -Quiet" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
    exit
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 2. Locate Grub2Win directory
if (-not $Grub2WinPath) {
    $candidate = "$env:SystemDrive\grub2"
    if (Test-Path "$candidate\grub.cfg") {
        $Grub2WinPath = $candidate
    } else {
        $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
        foreach ($d in $drives) {
            $test = Join-Path $d "grub2"
            if (Test-Path "$test\grub.cfg") {
                $Grub2WinPath = $test
                break
            }
        }
    }
}

if (-not $Grub2WinPath -or -not (Test-Path $Grub2WinPath)) {
    if ($Quiet) {
        Write-Error "Grub2Win directory could not be found automatically. Specify -Grub2WinPath."
        exit 1
    }
    Write-Host "[!] Grub2Win was not found at standard location ($env:SystemDrive\grub2)." -ForegroundColor Yellow
    $Grub2WinPath = Read-Host "Please enter the full path to your Grub2Win directory (e.g. C:\grub2)"
    if (-not (Test-Path "$Grub2WinPath\grub.cfg")) {
        Write-Error "Invalid Grub2Win directory: '$Grub2WinPath'. 'grub.cfg' was not found."
        exit 1
    }
}

Write-Host "=============================================" -ForegroundColor Green
Write-Host "   Minegrub Theme Installer for Grub2Win     " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "[*] Target Grub2Win: $Grub2WinPath" -ForegroundColor Cyan

# 3. Target folders
$targetThemeDir  = Join-Path $Grub2WinPath "themes\minegrub"
$targetFontsDir  = Join-Path $Grub2WinPath "fonts"
$targetWinSource = Join-Path $Grub2WinPath "winsource"
$targetGrubCfg   = Join-Path $Grub2WinPath "grub.cfg"

# 4. Copy theme assets
Write-Host "[*] Copying theme files..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $targetThemeDir -Force | Out-Null
Copy-Item -Path "$scriptDir\minegrub\*" -Destination $targetThemeDir -Recurse -Force

# Copy all background options into backgrounds folder for shuffling
$targetBgDir = Join-Path $targetThemeDir "backgrounds"
New-Item -ItemType Directory -Path $targetBgDir -Force | Out-Null
if (Test-Path "$scriptDir\background_options") {
    Get-ChildItem -LiteralPath "$scriptDir\background_options" -Filter "*.png" | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $targetBgDir -Force
    }
}

# 5. Copy fonts
Write-Host "[*] Copying Minecraft fonts..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $targetFontsDir -Force | Out-Null
Get-ChildItem -LiteralPath "$scriptDir\minegrub" -Filter "*.pf2" | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $targetFontsDir -Force
}

# 6. Adjust static bar position based on boot options count
# Formula: top = 40% + (72 * N + 26)
if ($BootOptionsCount -le 0) {
    if (Test-Path $targetGrubCfg) {
        $detected = (Get-Content $targetGrubCfg | Select-String "^\s*menuentry\s+").Count
        if ($detected -gt 0) {
            $BootOptionsCount = $detected
            Write-Host "[*] Detected $BootOptionsCount boot options from grub.cfg." -ForegroundColor Cyan
        }
    }
}

if ($BootOptionsCount -le 0) {
    $BootOptionsCount = 4
}

$calculatedOffset = (72 * $BootOptionsCount) + 26
$topValue = "40%+$calculatedOffset"
Write-Host "[*] Aligning bottom bar for $BootOptionsCount boot options (top = $topValue)..." -ForegroundColor Cyan

$themeTxt = Join-Path $targetThemeDir "theme.txt"
if (Test-Path $themeTxt) {
    $content = Get-Content $themeTxt -Raw
    $content = [System.Text.RegularExpressions.Regex]::Replace($content, "(?m)^\s*top\s*=\s*40%\+\d+", "`ttop = $topValue")
    Set-Content -Path $themeTxt -Value $content -Encoding UTF8
}

# 7. Patch Grub2Win templates for permanent persistence across GUI updates
if (Test-Path $targetWinSource) {
    Write-Host "[*] Patching Grub2Win templates for persistence..." -ForegroundColor Cyan
    
    # template.theme.cfg (points to theme and unsets icondir so icons don't overlap buttons)
    $templateTheme = Join-Path $targetWinSource "template.theme.cfg"
    $themeCfgContent = @"
set theme=`$prefix/themes/minegrub/theme.txt
unset icondir
export theme
"@
    Set-Content -Path $templateTheme -Value $themeCfgContent -Encoding UTF8 -Force

    # template.gfxfonts.cfg (loads Minecraft and Monocraft fonts)
    $templateFonts = Join-Path $targetWinSource "template.gfxfonts.cfg"
    if (Test-Path $templateFonts) {
        $fontLines = Get-Content $templateFonts
        $fontsToAdd = @(
            "loadfont `$prefix/fonts/Minecraft30.pf2",
            "loadfont `$prefix/fonts/Minecraft24.pf2",
            "loadfont `$prefix/fonts/Monocraft22.pf2"
        )
        $modified = $false
        foreach ($f in $fontsToAdd) {
            if ($fontLines -notcontains $f) {
                $fontLines += $f
                $modified = $true
            }
        }
        if ($modified) {
            Set-Content -Path $templateFonts -Value $fontLines -Encoding UTF8 -Force
        }
    }

    # template.gfxmenu.cfg (enforces 1920x1080 native widescreen resolution)
    $templateGfxMenu = Join-Path $targetWinSource "template.gfxmenu.cfg"
    if (Test-Path $templateGfxMenu) {
        $gfxMenuContent = Get-Content $templateGfxMenu -Raw
        if ($gfxMenuContent -match "if \[ ! -z \$grub2win_gfxmode \] ; then set gfxmode=\$grub2win_gfxmode ; fi") {
            $gfxMenuContent = $gfxMenuContent.Replace("if [ ! -z `$grub2win_gfxmode ] ; then set gfxmode=`$grub2win_gfxmode ; fi", "set gfxmode=1920x1080,auto")
            Set-Content -Path $templateGfxMenu -Value $gfxMenuContent -Encoding UTF8 -Force
        }
    }
}

# Update grubenv to 1920x1080 if present
$grubenvPath = Join-Path $Grub2WinPath "grubenv"
if (Test-Path $grubenvPath) {
    $rawEnv = [System.IO.File]::ReadAllText($grubenvPath)
    if ($rawEnv -match "grub2win_gfxmode=1024x768,auto") {
        $newEnv = $rawEnv.Replace("grub2win_gfxmode=1024x768,auto", "grub2win_gfxmode=1920x1080,auto")
        $lastHash = $newEnv.LastIndexOf('#')
        if ($lastHash -ge 0) { $newEnv = $newEnv.Remove($lastHash, 1) }
        [System.IO.File]::WriteAllText($grubenvPath, $newEnv)
    }
}

# Also populate userfiles/user.themes
$userThemesDir = Join-Path $Grub2WinPath "userfiles\user.themes"
if (Test-Path (Join-Path $Grub2WinPath "userfiles")) {
    New-Item -ItemType Directory -Path $userThemesDir -Force | Out-Null
    Copy-Item -Path $themeTxt -Destination (Join-Path $userThemesDir "custom.config.64.efi.txt") -Force
    Copy-Item -Path $themeTxt -Destination (Join-Path $userThemesDir "custom.config.64.bios.txt") -Force
    Copy-Item -Path $themeTxt -Destination (Join-Path $userThemesDir "custom.config.32.efi.txt") -Force
    Copy-Item -Path $themeTxt -Destination (Join-Path $userThemesDir "custom.config.32.bios.txt") -Force
}

# 8. Update active grub.cfg
if (Test-Path $targetGrubCfg) {
    Write-Host "[*] Updating live grub.cfg..." -ForegroundColor Cyan
    $cfgContent = Get-Content $targetGrubCfg -Raw

    if ($cfgContent -notmatch "set theme=\$prefix/themes/minegrub/theme\.txt") {
        $cfgContent = [System.Text.RegularExpressions.Regex]::Replace($cfgContent, "set theme=\$prefix/themes/custom\.config[\r\n]+if \[.*?\] ; then.*?fi", "set theme=`$prefix/themes/minegrub/theme.txt")
    }

    if ($cfgContent -match "export icondir") {
        $cfgContent = $cfgContent.Replace("export icondir", "unset icondir")
    }

    if ($cfgContent -notmatch "Minecraft30\.pf2") {
        $cfgContent = $cfgContent.Replace("source `$prefix/winsource/template.gfxfonts.cfg", "source `$prefix/winsource/template.gfxfonts.cfg`r`nloadfont `$prefix/themes/minegrub/Minecraft30.pf2`r`nloadfont `$prefix/themes/minegrub/Minecraft24.pf2`r`nloadfont `$prefix/themes/minegrub/Monocraft22.pf2")
    }

    if ($cfgContent -match "set gfxmode=1024x768,auto") {
        $cfgContent = $cfgContent.Replace("set gfxmode=1024x768,auto", "set gfxmode=1920x1080,auto")
    }

    if ($cfgContent -match "if \[ ! -z \$grub2win_gfxmode \] ; then set gfxmode=\$grub2win_gfxmode ; fi") {
        $cfgContent = $cfgContent.Replace("if [ ! -z `$grub2win_gfxmode ] ; then set gfxmode=`$grub2win_gfxmode ; fi", "set gfxmode=1920x1080,auto")
    }

    Set-Content -Path $targetGrubCfg -Value $cfgContent -Encoding UTF8 -Force
}

# 9. Copy background shuffler script into installed theme folder
$installedShuffler = Join-Path $targetThemeDir "shuffle-background.ps1"
Copy-Item -Path "$scriptDir\shuffle-background.ps1" -Destination $installedShuffler -Force

# 10. Register Scheduled Task for automatic background shuffling on logon
if (-not $NoShuffle) {
    Write-Host "[*] Registering background shuffle task on user logon..." -ForegroundColor Cyan
    $taskName = "MinegrubBackgroundShuffle"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installedShuffler`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Shuffles Minegrub GRUB theme background on each logon" -Force | Out-Null
    Write-Host "[+] Scheduled task '$taskName' registered successfully." -ForegroundColor Green

    # Run shuffler once immediately
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installedShuffler
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "   Minegrub installed successfully!          " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "Reboot your computer to see your Minecraft bootloader!" -ForegroundColor Yellow
if (-not $Quiet) {
    Write-Host ""
    Read-Host "Press Enter to exit..."
}
