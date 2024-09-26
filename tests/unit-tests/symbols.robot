*** Test Cases ***
Should Get Simple Symbol
    Execute Command               include @scripts/single-node/miv.resc
    ${addr}=  Execute Command     sysbus GetSymbolAddress "main"
    Should Be Equal As Numbers    0x8000097C  ${addr.strip()}

Should Get Simple Symbol By Index
    Execute Command               include @scripts/single-node/miv.resc
    ${addr}=  Execute Command     sysbus GetSymbolAddress "main" 0
    Should Be Equal As Numbers    0x8000097C  ${addr.strip()}

Should Get Complex Symbol By Index
    Execute Command               include @scripts/single-node/miv.resc
    ${addr}=  Execute Command     sysbus GetSymbolAddress "__compound_literal.3" 0
    Should Be Equal As Numbers    0x8004004C  ${addr.strip()}
    ${addr}=  Execute Command     sysbus GetSymbolAddress "__compound_literal.3" 1
    Should Be Equal As Numbers    0x80040078  ${addr.strip()}

Should Error On Wrong Index
    Execute Command               include @scripts/single-node/miv.resc
    Run Keyword And Expect Error  *Wrong index*   Execute Command  sysbus GetSymbolAddress "main" 1

Should Ask For Index
    Execute Command               include @scripts/single-node/miv.resc
    Run Keyword And Expect Error  *Found 4 possible addresses*   Execute Command  sysbus GetSymbolAddress "__compound_literal.3"

Should Get Simple Symbol From Python
    Execute Command               include @scripts/single-node/miv.resc
    ${addr}=  Execute Command     python "print(hex(self.Machine.SystemBus.GetSymbolAddress('main')))"
    Should Be Equal               0x8000097cL  ${addr.strip()}

Should Get Simple Symbol By Index From Python
    Execute Command               include @scripts/single-node/miv.resc
    ${addr}=  Execute Command     python "print(hex(self.Machine.SystemBus.GetSymbolAddress('main', 0)))"
    Should Be Equal               0x8000097cL  ${addr.strip()}

Should Get Complex Symbol By Index From Python
    Execute Command               include @scripts/single-node/miv.resc
    ${addr}=  Execute Command     python "print(hex(self.Machine.SystemBus.GetSymbolAddress('__compound_literal.3', 0)))"
    Should Be Equal               0x8004004cL  ${addr.strip()}
    ${addr}=  Execute Command     python "print(hex(self.Machine.SystemBus.GetSymbolAddress('__compound_literal.3', 1)))"
    Should Be Equal               0x80040078L  ${addr.strip()}

Should Error On Wrong Index From Python
    Execute Command               include @scripts/single-node/miv.resc
    Run Keyword And Expect Error  *Wrong index*   Execute Command  python "print(hex(self.Machine.SystemBus.GetSymbolAddress('main', 1)))"

Should Ask For Index From Python
    Execute Command               include @scripts/single-node/miv.resc
    Run Keyword And Expect Error  *Found 4 possible addresses*   Execute Command  python "print(hex(self.Machine.SystemBus.GetSymbolAddress('__compound_literal.3')))"
