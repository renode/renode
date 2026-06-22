*** Settings ***
Library     OperatingSystem
Library     String
Test Tags   basic-tests

*** Keywords ***
Should Throw Python Syntax Exception
    [Arguments]                     ${command}
    ${out}=                         Run Keyword And Expect Error  KeywordException:*
    ...                             Execute Command  ${command}
    Should Contain                  ${out}  [FatalError] unexpected token

*** Test Cases ***
Invalid Python Script In Filename Should Return Error
    ${pythonScript}=    Join Path           ${TEMPDIR}          invalid.py
    Create File         ${pythonScript}     invalid Python

    # Renode requires to escape "\" that might appear in Windows' path. As \ is the escape character
    # for Robot, it has to be escaped twice.
    ${pythonScript}=    Replace String      ${pythonScript}     \\           \\\\

    Execute Command     mach create
    Should Throw Python Syntax Exception
    ...                 machine LoadPlatformDescriptionFromString "p: Python.PythonPeripheral { size: 0; filename: \\"${TEMPDIR}/invalid.py\\" }"
