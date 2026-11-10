Set WshShell = CreateObject("WScript.Shell")

scriptPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & "\cleanup.ps1"

WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & scriptPath & """", 0, True

Set WshShell = Nothing