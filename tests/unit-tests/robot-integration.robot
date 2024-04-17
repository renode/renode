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
    Should Contain      ${msg}      File does not exist

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

Should Return Python Int
    ${res}=                         Execute Python  1 + 2
    # This doesn't really get the type of the returned value, but rather the type of the
    # result of evaluating `type(<returned value as a string>)`. There doesn't seem to be
    # a way to get the type of a variable itself without this stringifying and evaluation
    ${type}=                        Evaluate  type(${res}).__name__
    Should Be Equal                 ${type}  int
    Should Be Equal                 ${res}  ${3}

Should Return Python String
    ${res}=                         Execute Python  "{}bcd".format("a")
    ${type}=                        Evaluate  type("${res}").__name__
    Should Be Equal                 ${type}  str
    Should Be Equal                 ${res}  abcd

Should Return Python List
    ${expected}=                    Create List  ${0}  ${1}  ${2}  ${3}  ${4}
    ${res}=                         Execute Python  list(range(5))
    Lists Should Be Equal           ${res}  ${expected}

Should Propagate Python Exception
    Run Keyword And Expect Error    ValueErrorException*  Execute Python  raise ValueError()

Should Fail On Python Syntax Error
    Run Keyword And Expect Error    SyntaxErrorException*  Execute Python  "a
