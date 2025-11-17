*** Test Cases ***
Should Not Crash On Empty Platform String
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString ""
