/* ast2600_spl_stub.S - Minimal SPL boot stub for AST2600 Renode testing
 *
 * Exercises Tier 1 peripherals in realistic boot order:
 *   SCU  - unlock + read silicon revision
 *   SDMC - unlock + read DRAM config
 *   DRAM - write/read-back test pattern
 *   WDT  - disable watchdog (as real SPL does)
 *   UART - print "DRAM: 1 GiB" (the real SPL milestone string)
 *
 * Build: arm-linux-gnueabi-as -march=armv7-a -o spl.o ast2600_spl_stub.S
 *        arm-linux-gnueabi-ld -Ttext=0 -o spl.elf spl.o
 *        arm-linux-gnueabi-objcopy -O binary spl.elf spl.bin
 */

    .syntax unified
    .arch   armv7-a
    .text
    .global _start

_start:
    /* ----------------------------------------------------------------
     * 1. SCU: Unlock and read silicon revision
     * ---------------------------------------------------------------- */
    ldr     r0, =0x1E6E2000         @ SCU base
    ldr     r1, =0x1688A8A8         @ Protection key
    str     r1, [r0]                @ Unlock SCU

    ldr     r2, [r0, #0x04]         @ Read Silicon Revision (0x1E6E2004)
    /* r2 should be 0x05030303 = AST2600-A3 */

    /* ----------------------------------------------------------------
     * 2. SDMC: Unlock and read memory configuration
     * ---------------------------------------------------------------- */
    ldr     r0, =0x1E6E0000         @ SDMC base
    ldr     r1, =0xFC600309         @ SDMC protection key
    str     r1, [r0]                @ Unlock SDMC

    ldr     r3, [r0, #0x04]         @ Read MCR04 (config)
    /* r3 should be 0x3000000E: HW_VER=3, VGA=64MB, DRAM_SIZE=2 (1GiB) */

    /* Extract DRAM size from bits [3:2] */
    and     r4, r3, #0x0C           @ bits [3:2]
    lsr     r4, r4, #2              @ r4 = DRAM size index (expect 2 = 1GiB)

    /* ----------------------------------------------------------------
     * 3. WDT: Disable watchdog 1 (as real SPL does early in boot)
     * ---------------------------------------------------------------- */
    ldr     r0, =0x1E785000         @ WDT1 base
    ldr     r1, [r0, #0x0C]        @ Read WDT1 control
    bic     r1, r1, #0x01          @ Clear enable bit
    str     r1, [r0, #0x0C]        @ Disable WDT1

    /* ----------------------------------------------------------------
     * 4. DRAM: Write and read-back test pattern
     * ---------------------------------------------------------------- */
    ldr     r0, =0x80000000         @ DRAM base
    ldr     r1, =0xDEADBEEF
    str     r1, [r0]                @ Write pattern
    ldr     r5, [r0]                @ Read back
    cmp     r5, r1
    bne     dram_fail               @ Should never branch

    /* ----------------------------------------------------------------
     * 5. UART5: Print boot milestone string "DRAM: 1 GiB\r\n"
     *    NS16550 THR at offset 0x00 from UART base
     * ---------------------------------------------------------------- */
    ldr     r6, =0x1E784000         @ UART5 base (THR)
    adr     r7, boot_msg
    mov     r8, #14                 @ message length including \r\n
uart_loop:
    ldrb    r1, [r7], #1
    str     r1, [r6]                @ Write byte to THR
    subs    r8, r8, #1
    bne     uart_loop

    /* ----------------------------------------------------------------
     * 6. Boot complete - halt
     * ---------------------------------------------------------------- */
boot_done:
    wfi
    b       boot_done

dram_fail:
    ldr     r6, =0x1E784000
    adr     r7, fail_msg
    mov     r8, #12
fail_loop:
    ldrb    r1, [r7], #1
    str     r1, [r6]
    subs    r8, r8, #1
    bne     fail_loop
    b       boot_done

    .align 2
boot_msg:
    .ascii  "DRAM: 1 GiB\r\n"
    .align 2
fail_msg:
    .ascii  "DRAM FAIL!\r\n"
    .align 2
