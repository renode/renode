*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${CURDIR}/../../src/Renode/RobotFrameworkEngine/renode-keywords.robot

*** Keywords ***
Load Script
    [Arguments]  ${path}
    Reset Emulation
    Execute Script  ${path}

*** Test Cases ***
Should Load Demos
    [Template]  Load Script
        ${CURDIR}/../../scripts/single-node/efr32mg.resc
        ${CURDIR}/../../scripts/single-node/i386.resc
        ${CURDIR}/../../scripts/single-node/miv.resc
        ${CURDIR}/../../scripts/single-node/mpc5567.resc
        ${CURDIR}/../../scripts/single-node/quark_c1000.resc
        ${CURDIR}/../../scripts/single-node/sifive_fe310.resc
        ${CURDIR}/../../scripts/single-node/stm32f4_discovery.resc
        ${CURDIR}/../../scripts/single-node/stm32f746.resc
        ${CURDIR}/../../scripts/single-node/tegra3.resc
        ${CURDIR}/../../scripts/single-node/versatile.resc
        ${CURDIR}/../../scripts/single-node/vexpress.resc
        ${CURDIR}/../../scripts/single-node/vybrid.resc
        ${CURDIR}/../../scripts/single-node/zedboard.resc
        ${CURDIR}/../../scripts/multi-node/quark-c1000-zephyr/demo.resc
