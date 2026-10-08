*** Variables ***
${SCB_ICSR}                         0xE000ED04
${SCB_AIRCR}                        0xE000ED0C
${SCB_CCR}                          0xE000ED14
${SCB_SHCSR}                        0xE000ED24
${SCB_CFSR}                         0xE000ED28
${SCB_CFSR_NS}                      0xE002ED28
${SCB_HFSR}                         0xE000ED2C
${SCB_BFAR}                         0xE000ED38
${SCB_BFAR_NS}                      0xE002ED38
${SCB_CPACR}                        0xE000ED88
${SCB_NSACR}                        0xE000ED8C
${SCB_SFSR}                         0xE000EDE4
${SCB_SFAR}                         0xE000EDE8
${SCB_DHCSR}                        0xE000EDF0
${SCB_DHCSR_NS}                     0xE002EDF0
${SCB_FPCCR}                        0xE000EF34
${SCB_FPCAR}                        0xE000EF38

${NVIC_ISPR0}                       0xE000E200
${NVIC_IABR0}                       0xE000E300
${NVIC_ITNS0}                       0xE000E380

${CCR_BFHFNMIGN}                    ${{1<<8}}

${SHCSR_BUSFAULTACT}                ${{1<<1}}
${SHCSR_HARDFAULTACT}               ${{1<<2}}
${SHCSR_NMIACT}                     ${{1<<5}}
${SHCSR_BUSFAULTPENDED}             ${{1<<14}}
${SHCSR_BUSFAULTENA}                ${{1<<17}}
${SHCSR_HARDFAULTPENDED}            ${{1<<21}}
${SHCSR_HARDFAULTACT_NMIACT}        ${{ ${SHCSR_HARDFAULTACT} | ${SHCSR_NMIACT} }}

${CFSR_UNSTKERR}                    ${{1<<11}}
${CFSR_STKERR}                      ${{1<<12}}
${CFSR_LSPERR}                      ${{1<<13}}
${CFSR_INVSTATE}                    ${{1<<17}}
${CFSR_INVPC}                       ${{1<<18}}
${CFSR_PRECISERR_BFARVALID}         ${{(1<<9) | (1<<15)}}

${HFSR_VECTTBL}                     ${{1<<1}}
${HFSR_FORCED}                      ${{1<<30}}

${SFSR_INVEP}                       ${1}
${SFSR_INVIS}                       ${{1<<1}}
${SFSR_INVER}                       ${{1<<2}}
${SFSR_AUVIOL}                      ${{1<<3}}
${SFSR_INVTRAN}                     ${{1<<4}}
${SFSR_SFARVALID}                   ${{1<<6}}

${DHCSR_S_LOCKUP}                   ${{1<<19}}

${FPCCR_LSPACT}                     ${{1<<0}}
${FPCCR_HFRDY}                      ${{1<<4}}
${FPCCR_TS}                         ${{1<<26}}
${FPCCR_LSPEN}                      ${{1<<30}}

${CONTROL_FPCA}                     ${{1<<2}}

${AIRCR_VECTKEY_BFHFNMINS}          0x05FA2000

${CPACR_CP10_CP11_FULL_ACCESS}      0x00F00000
${NSACR_CP10_CP11_FULL_ACCESS}      0x00000C00
