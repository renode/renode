@echo off
setlocal EnableDelayedExpansion
set PATH=C:\cygwin64\bin\;%PATH%
set PLATFORM=Any CPU
for /r %%i in (*.sh) do  CALL :convert_to_unix_newline %%i

call bash build.sh

REM Need to use call for all functions outside of script, otherwise label handling go crazy
call mkdir %LIBRARY_PREFIX%\renode\exec
call mkdir %LIBRARY_PREFIX%\renode\tests
call mkdir %LIBRARY_PREFIX%\renode\scripts
call mkdir %LIBRARY_PREFIX%\renode\platforms
call mkdir %LIBRARY_PREFIX%\renode\licenses
call robocopy output\bin\Release\ %LIBRARY_PREFIX%\renode\exec\ /njh /njs /ndl /S
call robocopy tests\ %LIBRARY_PREFIX%\renode\tests /njh /njs /ndl /S
call robocopy scripts\ %LIBRARY_PREFIX%\renode\scripts /njh /njs /ndl /S
call robocopy platforms\ %LIBRARY_PREFIX%\renode\platforms /njh /njs /ndl /S
call robocopy .\ %LIBRARY_PREFIX%\renode\ .renode-root
call robocopy .\ %LIBRARY_PREFIX%\renode\ LICENSE

REM copy all licenses
call copy lib\resources\tools\nunit-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\Moq-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\LZ4-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\IronPython-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\Dynamitey-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\Mono.TextTemplating-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\Mono.Cecil-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\Mono.Linq.Expressions-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\Sprache-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\CookComputing.XmlRpcV2-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\NetMQ-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\AsyncIO-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\Nini-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\LZ4n-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\libraries\Lucene.Net-license %LIBRARY_PREFIX%\renode\licenses\
call copy lib\resources\fonts\RobotoMono-Regular-license %LIBRARY_PREFIX%\renode\licenses\
call copy tools\packaging\macos\macos_run.command-license %LIBRARY_PREFIX%\renode\licenses\
call copy src\Infrastructure\src\Emulator\Cores\tlib\tcg\LICENSE %LIBRARY_PREFIX%\renode\licenses\tcg-license
call copy src\Infrastructure\src\Emulator\Cores\tlib\LICENSE %LIBRARY_PREFIX%\renode\licenses\tlib-license
call copy lib\options-parser\LICENSE %LIBRARY_PREFIX%\renode\licenses\options-parser-license
call copy lib\ELFSharp\LICENSE %LIBRARY_PREFIX%\renode\licenses\ELFSharp-license
call copy lib\Packet.Net\LICENSE %LIBRARY_PREFIX%\renode\licenses\Packet.Net-license
call copy lib\termsharp\LICENSE %LIBRARY_PREFIX%\renode\licenses\termsharp-license
call copy lib\Migrant\LICENSE %LIBRARY_PREFIX%\renode\licenses\Migrant-license
call copy lib\FdtSharp\LICENCE %LIBRARY_PREFIX%\renode\licenses\FdtSharp-license
call copy lib\xwt\LICENSE.txt %LIBRARY_PREFIX%\renode\licenses\xwt-license
call copy tools\packaging\windows\mingw-license %LIBRARY_PREFIX%\renode\licenses\mingw-license
call copy tools\packaging\windows\winpthreads-license %LIBRARY_PREFIX%\renode\licenses\winpthreads-license


REM Add activation script to append renode dir to PATH
if not exist %PREFIX%\etc\conda\activate.d call mkdir %PREFIX%\etc\conda\activate.d
call copy %RECIPE_DIR%\activate.bat %PREFIX%\etc\conda\activate.d\%PKG_NAME%_activate.bat

EXIT /B 0

:convert_to_unix_newline
powershell -Command "(Get-Content %~1 -Raw).Replace(\"`r\",\"\") |Set-Content -NoNewLine %~1 -Force"
EXIT /B 0

