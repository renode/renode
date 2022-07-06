*** Variables ***
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Prepare Machine
    Execute Command           using sysbus
    Execute Command           mach create "ARM"

    Execute Command           machine LoadPlatformDescriptionFromString "cpu: CPU.CortexM @ sysbus { cpuType: \\"cortex-m4f\\"; nvic: nvic }; nvic: IRQControllers.NVIC @ sysbus 0xE000E000 { -> cpu@0 }"
    Execute Command           machine LoadPlatformDescriptionFromString "rom: Memory.MappedMemory @ sysbus 0x0 { size: 0x40000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "ram: Memory.MappedMemory @ sysbus 0x20000000 { size: 0x100000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "serial: UART.TrivialUart @ sysbus 0x40000000"
    Create Terminal Tester    sysbus.serial

*** Test Cases ***
Should Successfully Run ARM CMSIS-DSP Bayes Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_bayes_example-s_507204-e7a628ba214a783da267aa0ad020a17b4a639023
    Start Emulation

    Wait For Line On Uart     Class = 0
    Wait For Line On Uart     Class = 1
    Wait For Line On Uart     Class = 2

Should Successfully Run ARM CMSIS-DSP Class Marks Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_class_marks_example-s_512880-20dc1258703a507ecbb8aa90a1e7acc40283ab49
    Start Emulation

    Wait For Line On Uart     mean = 212.3[0-9]*, std = 50.9      treatAsRegex=true

Should Successfully Run ARM CMSIS-DSP Convolution Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_convolution_example-s_527464-f021944bc003161d6df52cd9bbd32ca97aa28c2a
    Start Emulation

    Wait For Line On Uart     SUCCESS

Should Successfully Run ARM CMSIS-DSP Dotproduct Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_dotproduct_example-s_497436-cf26bc832acfc3c0fd2a537ff6f0e36c0f0172e1
    Start Emulation

    Wait For Line On Uart     SUCCESS

Should Successfully Run ARM CMSIS-DSP FFT Bin Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_fft_bin_example-s_604476-5d8048f7059da9e37dc30224cd5aa74e1565155e
    Start Emulation

    Wait For Line On Uart     SUCCESS

Should Successfully Run ARM CMSIS-DSP FIR Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_fir_example-s_510172-03c41dfef01b0b66a5c49bcd209a78f8d8b91160
    Start Emulation

    Wait For Line On Uart     SUCCESS

Should Successfully Run ARM CMSIS-DSP Graphic Equalizer Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_graphic_equalizer_example-s_522692-caa2b4f68c8a7ca1b5ed048eb32b93d220244ff6
    Start Emulation

    Wait For Line On Uart     SUCCESS

Should Successfully Run ARM CMSIS-DSP Linear Interp Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_linear_interp_example-s_514692-2901143773db5391a8c385074ea767c3641ec50e
    Start Emulation

    Wait For Line On Uart     SUCCESS

Should Successfully Run ARM CMSIS-DSP Matrix Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_matrix_example-s_510168-829948702fc106f9364a750405c386ae1ada9b14
    Start Emulation

    Wait For Line On Uart     SUCCESS

Should Successfully Run ARM CMSIS-DSP Signal Convergence Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_signal_convergence_example-s_516952-9d2773124f7b773e221c32b6fb68152ad9dddf35
    Start Emulation

    Wait For Line On Uart     SUCCESS

Should Successfully Run ARM CMSIS-DSP Sin Cos Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_sin_cos_example-s_508376-54497ea45b654a5587649f98084a979a204506ad
    Start Emulation

    Wait For Line On Uart     SUCCESS

Should Successfully Run ARM CMSIS-DSP SVM Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_svm_example-s_506948-254f2b8aff2adae8bc26bd48d6bd7d18dcfb49d7
    Start Emulation

    Wait For Line On Uart     Result = 0
    Wait For Line On Uart     Result = 1

Should Successfully Run ARM CMSIS-DSP Variance Example
    Prepare Machine
    Execute Command           sysbus LoadELF ${URI}/arm_variance_example-s_501832-107cb91eec0bde73d269578dc0f78ab223cca4f8
    Start Emulation

    Wait For Line On Uart     SUCCESS
