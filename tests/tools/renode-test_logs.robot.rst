Note about this file
--------------------


This file is formatted as reStructuredText to make it clear that it's not a standalone test suite
(.robot files). It is intended to be used by `renode-test.robot <./renode-test.robot>`_.


Testing robot framework messages
--------------------------------------

When the robot framework itself logs an error or warning messages, it should be displayed in
console. Below is an example of not found library that produces an error and the usage of a
deprecated keyword that produces a warning.

Keyword logging messages should also be displayed on console.

.. code:: robotframework

    *** Settings ***
    Library         Not Found Library
    Suite Setup     No Operation    # No need to run Renode, so override the default setup
    Suite Teardown  No Operation
    Test Setup      No Operation
    Test Teardown   No Operation

    *** Keywords ***
    Deprecated Keyword
        [Documentation]     *DEPRECATED*
        Log     Nothing


    *** Test Cases ***
    Log Messages
        Log     This is a trace     level=TRACE
        Log     This is a debug     level=DEBUG
        Log     This is an info     level=INFO
        Log     This is a warning   level=WARN
        Log     This is an error    level=ERROR

    Call Deprecated Keyword
        Deprecated Keyword
