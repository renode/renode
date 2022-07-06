*** Variables ***
${AUDIO_INPUT}                https://dl.antmicro.com/projects/renode/sine440_with_beep_aligned.pcm_s24le_44100_stereo.raw-s_793344-b37432aad6a22f36cb5c1e239c9bce4adbcd15fb

*** Test Cases ***
Should Echo Audio
    ${input_file}=            Download File  ${AUDIO_INPUT}

    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/litex_zephyr_vexriscv_i2s.repl
    Execute Command           showAnalyzer sysbus.uart
    Execute Command           sysbus LoadELF @https://dl.antmicro.com/projects/renode/litex_i2s--zephyr-echo_sample.elf-s_1172756-db2f7eb8c6c8f396651b2f2d517cee13d79a9a69

    ${output_file}=           Allocate Temporary File

    Execute Command           sysbus.i2s_tx Output @${output_file}
    Execute Command           sysbus.i2s_rx LoadPCM @${input_file}

    # sample input file is around 3s long, but let's give some more time for processing
    Execute Command           emulation RunFor "3.2"

    # in order to make sure the output file is closed
    Execute Command           sysbus.i2s_tx Dispose

    ${input_file_size}=       Get File Size  ${input_file}
    ${output_file_size}=      Get File Size  ${output_file} 

    Should Be Equal           ${input_file_size}  ${output_file_size}

    ${input_file_content}=    Get Binary File  ${input_file}
    ${output_file_content}=   Get Binary File  ${output_file}

    Should Be Equal           ${input_file_content}  ${output_file_content}

