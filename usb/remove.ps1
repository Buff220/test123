$ErrorActionPreference = 'SilentlyContinue'

Write-Host "Scanning system for infected drives..." -ForegroundColor Cyan

# Get all logical disks on the system
$drives = Get-CimInstance Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
$foundInfection = $false

foreach ($drive in $drives) {
    $root      = "$drive\"
    $usbFolder = Join-Path $root "USB_Drive"
    $lnkPath   = Join-Path $root "Open USB Drive.lnk"

    # Detect if this drive has the virus signature
    if ((Test-Path -LiteralPath $usbFolder) -or (Test-Path -LiteralPath $lnkPath)) {
        $foundInfection = $true
        Write-Host "`n[!] Infection detected on drive: $root" -ForegroundColor Red

        # 1. Clear Hidden, System, and Read-only attributes
        Write-Host " -> Restoring file and folder visibility..." -ForegroundColor Yellow
        & "$env:windir\System32\attrib.exe" -r -h -s "$root*" /s /d 2>$null

        # 2. Move contents out of 'USB_Drive' back to the root directory
        if (Test-Path -LiteralPath $usbFolder) {
            Write-Host " -> Moving files back from 'USB_Drive' to root..." -ForegroundColor Yellow
            Get-ChildItem -LiteralPath $usbFolder -Force | ForEach-Object {
                $destPath = Join-Path $root $_.Name
                if (Test-Path -LiteralPath $destPath) {
                    Remove-Item -LiteralPath $destPath -Recurse -Force -ErrorAction SilentlyContinue
                }
                Move-Item -LiteralPath $_.FullName -Destination $root -Force
            }
            Remove-Item -LiteralPath $usbFolder -Force -Recurse -ErrorAction SilentlyContinue
        }

        # 3. Remove the malicious shortcut
        if (Test-Path -LiteralPath $lnkPath) {
            Write-Host " -> Removing malicious shortcut..." -ForegroundColor Yellow
            Remove-Item -LiteralPath $lnkPath -Force
        }

        # 4. Find and remove hidden random payload directories containing payload.vbs
        Write-Host " -> Removing hidden payload folders..." -ForegroundColor Yellow
        Get-ChildItem -LiteralPath $root -Force -Directory | ForEach-Object {
            $vbsCheck = Join-Path $_.FullName "payload.vbs"
            if (Test-Path $vbsCheck) {
                Write-Host "    Deleting payload directory: $($_.Name)" -ForegroundColor DarkYellow
                Remove-Item -LiteralPath $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
            }
        }

        Write-Host " -> Drive $root cleaned successfully!" -ForegroundColor Green
    }
}

if (-not $foundInfection) {
    Write-Host "`nNo infected drives detected." -ForegroundColor Green
}

# 5. Clean local machine Startup folder
$localStartup = Join-Path ([Environment]::GetFolderPath('Startup')) "payload.vbs"
if (Test-Path $localStartup) {
    Write-Host "`n[!] Removing persistent payload from local Windows Startup folder..." -ForegroundColor Yellow
    Remove-Item -LiteralPath $localStartup -Force -ErrorAction SilentlyContinue
    Write-Host " -> Local startup folder cleaned." -ForegroundColor Green
} else {
    Write-Host "`nLocal startup folder is already clean." -ForegroundColor Green
}

Write-Host "`nScan and cleanup process complete!" -ForegroundColor Cyan
