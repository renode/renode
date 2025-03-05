*** Settings ***
Library  Collections
Library  OperatingSystem
Library  Process

*** Variables ***
${RDL_DIR}        ${CURDIR}/rdl/
${REFERENCE_DIR}  ${CURDIR}/reference/
${GENERATED_DIR}  ${CURDIR}/generated/
${RENODE_DIR}     ${CURDIR}/renode/

*** Test Cases ***
Compare Generated Files To References
    Create Directory  ${GENERATED_DIR}
    Execute Command  include @${CURDIR}/renode/EmptyPeripheral.cs
    ${files}  List Files In Directory  ${RDL_DIR}
    FOR  ${file}  IN  @{files}
        ${pathToRdl} =  Join Path  ${RDL_DIR}  ${file}

        ${baseName}  ${extension} =  Split Extension  ${file}
        ${replFileName}  Catenate  SEPARATOR=  ${baseName}  .repl
        ${pathToRef} =  Join Path  ${REFERENCE_DIR}  ${replFileName}
        ${pathToGen} =  Join Path  ${GENERATED_DIR}  ${replFileName}
        ${pathToRen} =  Join Path  ${RENODE_DIR}  ${baseName}_parent.repl

        Run Process  peakrdl  renode-repl  ${pathToRdl}  -o  ${pathToGen}
        ${ref} =  Get File  ${pathToRef}
        ${gen} =  Get File  ${pathToGen}
        Should Be Equal As Strings  ${ref}  ${gen}

        Execute Command  mach create
        Execute Command  include @${pathToRen}
        Execute Command  mach clear
    END
