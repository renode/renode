*** Settings ***
Suite Setup                   Get Test Cases

*** Variables ***
@{scripts_path}=              ${CURDIR}/../../scripts
@{pattern}=                   *.resc
@{excludes}=                  complex

*** Keywords ***
Get Test Cases
    Setup
    @{scripts}=  List Files In Directory Recursively  @{scripts_path}  @{pattern}  @{excludes}
    Set Suite Variable  @{scripts}

Load Script
    [Arguments]               ${path}
    Execute Script            ${path}

*** Test Cases ***
Should Load Demos
    FOR  ${script}  IN  @{scripts}
        Load Script  ${script}
        Reset Emulation 
    END
#Should Run Murax
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/murax_verilated_uart.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/murax_verilated_uart.resc
#    Reset Emulation

#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/multi-node/sam_e70.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/multi-node/nrf52840-ble-zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/multi-node/da16200.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/multi-node/nrf52840-ble-hci-uart-zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/multi-node/cc2538/rpl-udp.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/multi-node/quark-c1000-zephyr/quark_c1000.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/multi-node/quark-c1000-zephyr/demo.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/sltb004a.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/zolertia.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/andes_ae350_zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/zedboard.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/sam4s.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/sam_e70.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_vexriscv.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/riscv_verilated_liteuart.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/zynqmp_linux.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/quickfeather.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/stm32l072.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/cortex-r52-hirtos.resc
#    Reset Emulation

#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/veer_el2-tock.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/riscv_verilated_uartlite.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/cortex-r52-xen-zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/verilated_ibex.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/hifive_unmatched_sdcard.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/arvsom.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/sifive_fe310.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_vexriscv_linux.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_vexriscv_verilated_cfu.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/hifive_unmatched-tbm.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/murax.resc
#    Reset Emulation

#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_minerva.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/cortex-a53.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/stm32f746.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/qomu.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/stm32f4_tock.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/opentitan-earlgrey.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/microwatt.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/tegra3.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/beaglev-fire.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/murax_verilated_uart.resc
#    Reset Emulation

#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/renesas-da14592.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/kendryte_k210.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/nrf52840.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/max32652-evkit.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/cortex-a78-linux.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/icicle-kit.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/i386_zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_vexriscv_zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/zynqmp_openamp.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/acrn_x86_64_zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/stm32f746_mbed.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/zynq_verilated_fastvdma.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/stm32f4_discovery.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/ek-ra8m1.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/fsl_lx2160ardb_uboot.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/arty_litex_vexriscv.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/ck-ra6m5.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/xtensa.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/ambiq-apollo4.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/hifive_unleashed.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/zynqmp_zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/gr716_zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/quark_c1000.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_ibex.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/vegaboard_ri5cy.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/beaglev_starlight.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/cc2538.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/zynq_verilated_fpga_isp.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/cortex-r52.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/zynqmp_remoteproc.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_vexriscv_smp.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/stm32f103.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_vexriscv_tock.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/leon3_zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/polarfire-soc.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_vexriscv_micropython.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/ek-ra2e1.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_nexys_video_vexriscv_linux.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_microwatt.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/vexpress.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/hifive_unmatched.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_vexriscv_tftp.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/efr32mg.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/vybrid.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/picosoc.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/miv.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/gr712rc.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/stm32f746_modem.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/cortex-a53-linux.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/arduino_uno_r4_minima.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/mpc5567.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/up_squared_x86_64_zephyr.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/litex_vexriscv_sdcard.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/versatile.resc
#    Reset Emulation
#    Load Script  /mnt/hdd/src/renode-hq-dpi-mult-conns/src/renode/tests/unit-tests/../../scripts/single-node/i386.resc
#    Reset Emulation
