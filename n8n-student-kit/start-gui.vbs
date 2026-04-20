Set sh = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
sh.CurrentDirectory = baseDir
cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File """ & baseDir & "\N8N-Student-Kit-GUI.ps1"""
sh.Run cmd, 0, False
