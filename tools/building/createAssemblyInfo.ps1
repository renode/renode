#!/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe

$CURRENT_VERSION = Get-Content "..\..\..\tools\version"
$CURRENT_INFORMATIONAL_VERSION = git rev-parse --short=8 HEAD
$FILE_NAME = "AssemblyInfo"
if ( !(Test-Path "$FILE_NAME.cs") -or
     !(Select-String -q $CURRENT_VERSION "$FILE_NAME.cs") -or
     !(Select-String -q $CURRENT_INFORMATIONAL_VERSION "$FILE_NAME.cs"))
{
    (-join ((Get-Content "$FILE_NAME.template") -join [Environment]::NewLine)).`
    replace('%INFORMATIONAL_VERSION%',
        ('{0}-{1}' -f $CURRENT_INFORMATIONAL_VERSION, (Get-Date -Format yyyyMMddHHmm))).`
         replace("%VERSION%", $CURRENT_VERSION)|
        Set-Content -Path "$FILE_NAME.cs"
}

# keep the new lines
