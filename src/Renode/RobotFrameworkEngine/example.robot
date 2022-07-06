# ignore test

*** Test Cases ***
Should Print Help
    ${x}=  Execute Command     help
           Should Contain      ${x}    Available commands:
