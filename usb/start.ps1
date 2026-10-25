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
            & "$env:windir\System32\attrib.exe" -r -h -s "$Root*" /s /d 2>$null

            if (Test-Path -LiteralPath $DecoyFolder -PathType Container) {
                Get-ChildItem -LiteralPath $DecoyFolder -Force | ForEach-Object {
                    $DestPath = Join-Path $Root $_.Name
                    if (Test-Path -LiteralPath $DestPath) {
                        Remove-Item -LiteralPath $DestPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Move-Item -LiteralPath $_.FullName -Destination $Root -Force
                }
                Remove-Item -LiteralPath $DecoyFolder -Recurse -Force
            }

            if (Test-Path -LiteralPath $LnkFile) {
                Remove-Item -LiteralPath $LnkFile -Force
            }
            foreach ($folder in $RandomFolders) {
                Remove-Item -LiteralPath $folder.FullName -Recurse -Force
            }
        }
    }
}
