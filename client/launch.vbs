' DeepSeek desktop client launcher (relocatable, no console window)
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
base = fso.GetParentFolderName(WScript.ScriptFullName)
root = fso.GetParentFolderName(base)
Set env = sh.Environment("Process")
env("DSH_HOME") = root & "\home\.dsh"
env("PATH") = root & "\runtime\node;" & env("PATH")
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & base & "\client.ps1""", 0, False
