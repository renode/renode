*** Test Cases ***
Should Fail On Loading Nonexisting Script
    ${msg}=     Run Keyword And Expect Error        *   Execute Script      nonexistingscript.resc
    Should Contain      ${msg}      Could not find file

Should Fail On Builtin With Invalid Parameters
    ${msg}=     Run Keyword And Expect Error        *   Execute Command     log invalid_commmand
    Should Contain      ${msg}      Bad parameters for command

Should Fail On Peripheral Method With Invalid Parameters
    ${msg}=     Run Keyword And Expect Error        *   Execute Command     Save invalid_value
    Should Contain      ${msg}      Parameters did not match the signature

Should Fail On Python Command With Invalid Parameters
    ${msg}=     Run Keyword And Expect Error        *   Execute Command     next_value invalid_value
    Should Contain      ${msg}      unsupported operand type

Should Fail On Command Error
    ${msg}=     Run Keyword And Expect Error        *   Execute Command     include @nonexistingfile
    Should Contain      ${msg}      No such file

Should Allow Passing Python Float As Float Argument
    ${flt}=                         Evaluate  float(1)
    Create Log Tester               ${flt}

Should Allow Passing Python Int As Float Argument
    ${flt}=                         Evaluate  int(1)
    Create Log Tester               ${flt}

Should Allow Passing Python String As Argument
    # This is also what happens when for example `Create Log Tester  1` is used
    # (so in the typical case)
    ${str}=                         Evaluate  str(1)
    Create Log Tester               ${str}
