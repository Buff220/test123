$ErrorActionPreference = 'SilentlyContinue'

Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 } | ForEach-Object {
    $Root = "$($_.DeviceID)\"
    if (Test-Path -LiteralPath $Root) {
        $DecoyFolder = Join-Path $Root 'USB_Drive'
        $LnkFile = Join-Path $Root 'Open USB Drive.lnk'
        $RandomFolders = Get-ChildItem -LiteralPath $Root -Force | Where-Object { 
            $_.PSIsContainer -and $_.Name.Length -eq 10 -and $_.Name -match '^[a-z0-9]+$' 
        }

        if ((Test-Path -LiteralPath $DecoyFolder) -or (Test-Path -LiteralPath $LnkFile) -or ($RandomFolders)) {
            
            # 1. Unhide the USB_Drive folder so you can open it normally
            if (Test-Path -LiteralPath $DecoyFolder) {
                & "$env:windir\System32\attrib.exe" -r -h -s "$DecoyFolder" 2>$null
            }

            # 2. Delete the malicious shortcut lure
            if (Test-Path -LiteralPath $LnkFile) {
                Remove-Item -LiteralPath $LnkFile -Force
            }
            
            # 3. Delete any random 10-character hidden malware folders
            foreach ($folder in $RandomFolders) {
                & "$env:windir\System32\attrib.exe" -r -h -s "$($folder.FullName)" 2>$null
                Remove-Item -LiteralPath $folder.FullName -Recurse -Force
            }
        }
    }
}
