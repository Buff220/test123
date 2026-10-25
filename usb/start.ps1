# ==========================================
# All-Drive Malware Detector & Cleanup Script
# ==========================================
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "Scanning all system drives for USB malware infection..." -ForegroundColor Cyan

# Get all fixed and removable drives (DriveType 2 = Removable, 3 = Local Disk)
$Drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }

foreach ($Drive in $Drives) {
    $DriveLetter = $Drive.DeviceID # e.g., "C:", "D:"
    $Root = "$DriveLetter\"
    
    if (-not (Test-Path -LiteralPath $Root)) { continue }

    # Check for infection indicators on this drive
    $DecoyFolder = Join-Path $Root 'USB_Drive'
    $LnkFile = Join-Path $Root 'Open USB Drive.lnk'
    
    # Also look for random 10-character folders with Hidden/System attributes
    $HasRandomFolder = $false
    $RandomFolders = Get-ChildItem -LiteralPath $Root -Force | Where-Object { 
        $_.PSIsContainer -and $_.Name.Length -eq 10 -and $_.Name -match '^[a-z0-9]+$' 
    }

    if ((Test-Path -LiteralPath $DecoyFolder) -or (Test-Path -LiteralPath $LnkFile) -or ($RandomFolders)) {
        Write-Host "`n[!] INFECTION DETECTED on drive: $DriveLetter" -ForegroundColor Red

        # 1. Clear Hidden, System, and Read-only attributes
        Write-Host " -> Removing Hidden/System attributes..." -ForegroundColor Yellow
        & "$env:windir\System32\attrib.exe" -r -h -s "$Root*" /s /d 2>$null

        # 2. Restore files from 'USB_Drive' back to root if present
        if (Test-Path -LiteralPath $DecoyFolder -PathType Container) {
            Write-Host " -> Restoring files from 'USB_Drive' back to root..." -ForegroundColor Yellow
            Get-ChildItem -LiteralPath $DecoyFolder -Force | ForEach-Object {
                $DestPath = Join-Path $Root $_.Name
                if (Test-Path -LiteralPath $DestPath) {
                    Remove-Item -LiteralPath $DestPath -Recurse -Force -ErrorAction SilentlyContinue
                }
                Move-Item -LiteralPath $_.FullName -Destination $Root -Force
            }
            Remove-Item -LiteralPath $DecoyFolder -Recurse -Force
        }

        # 3. Clean up malware shortcuts and random hidden payload folders
        Write-Host " -> Deleting malware artifacts and shortcuts..." -ForegroundColor Yellow
        if (Test-Path -LiteralPath $LnkFile) {
            Remove-Item -LiteralPath $LnkFile -Force
        }
        foreach ($folder in $RandomFolders) {
            Remove-Item -LiteralPath $folder.FullName -Recurse -Force
        }

        Write-Host " [+] Drive $DriveLetter has been successfully cleaned!" -ForegroundColor Green
    } else {
        Write-Host "[✓] Clean: $DriveLetter" -ForegroundColor DarkGray
    }
}

Write-Host "`nScan and cleanup finished across all drives." -ForegroundColor Cyan
