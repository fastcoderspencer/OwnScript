Dim Wsh
Set Wsh = WScript.CreateObject("WScript.Shell")
Wsh.Run "taskkill /f /im alist.exe",0
Set Wsh=NoThing
WScript.quit