#!/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe

$CURRENT_VERSION = git rev-parse --short=8 HEAD
$FILE_NAME = "AssemblyInfo"
if (!(Test-Path "$FILE_NAME.cs") -or !(Select-String -q $CURRENT_VERSION "$FILE_NAME.cs")) { (-join ((Get-Content "$FILE_NAME.template") -join [Environment]::NewLine)).replace('%VERSION%', ('{0}-{1}' -f $CURRENT_VERSION, (Get-Date -Format yyyyMMddHHmm))) | Set-Content -Path "$FILE_NAME.cs" }
