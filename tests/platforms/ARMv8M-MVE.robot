*** Variables ***
${URI}                              @https://dl.antmicro.com/projects/renode

# CMSIS-DSP tests
${BAYES_ELF}                        ${URI}/arm_bayes_example-s_533068-1b83380598c43c98e36196b0d3b6e5557c2a0b35
${CLASS_MARKS_ELF}                  ${URI}/arm_class_marks_example-s_534536-d70b3e3e734a39133c11413daae2b0993d357032
${FIR_ELF}                          ${URI}/arm_fir_example-s_530876-a16180ffd6bddff383adbd5fdb38b32e7ebb89be
${MATRIX_ELF}                       ${URI}/arm_matrix_example-s_530856-9229a0ab3b3ad36b08ab55301753d3dd646a7a13
${VARIANCE_ELF}                     ${URI}/arm_variance_example-s_510304-06b1d60b4fe709c268f71751958947a9e263bff1
${SVM_ELF}                          ${URI}/arm_svm_example-s_519296-83fb108d4dc684e03332a720feeadb9638ce9d39
${SIN_COS_ELF}                      ${URI}/arm_sin_cos_example-s_515204-2cbb4a49d4dff96051aba824f052173f208210f6
${SIGNAL_CONVERGENCE_ELF}           ${URI}/arm_signal_convergence_example-s_546696-07a78b7febd04627a2ca8fce8c4f47d50d5518d6
${LINEAR_INTERP_ELF}                ${URI}/arm_linear_interp_example-s_515324-430c71458e54742b6bbb2b9c28a8ae3663dbc92c
${DOTPRODUCT_ELF}                   ${URI}/arm_dotproduct_example-s_503872-e7f6bd2c62df3d3e76281ca41ef1122ef7b4621a
${CONVOLUTION_ELF}                  ${URI}/arm_convolution_example-s_534496-2cf2f4427c7e3b9b05e5bf2046ef453946722e71
${FFT_BIN_ELF}                      ${URI}/arm_fft_bin_example-s_664164-c93c480209b4dd212db6760d93c357f0b14e47e9
${GRAPHIC_EQUALIZER_ELF}            ${URI}/arm_graphic_equalizer_example-s_539792-75bce13a23aef301a426d7536b07de84757c532f

@{CMSIS-NN_ELFS}                    ${URI}/binary_size_test-s_299768-b0d746609663afd996cf02628a873829ade93526
...                                 ${URI}/detection_responder_test-s_299936-1fc80afa5b28022589f1a8a12d397e324954aa99
...                                 ${URI}/dtln_test-s_772716-544d7400464c04de65fc72c8a747d539f3870943
...                                 ${URI}/fake_micro_context_test-s_309364-db8f07d6b85d4664f08b45b491990e20030168cd
...                                 ${URI}/flatbuffer_utils_test-s_422604-a8ae5980edf4d72df54cfd3d3294164b087282ae
...                                 ${URI}/greedy_memory_planner_test-s_311224-d7c8f1a496a764cee6b42290f429761beb476140
...                                 ${URI}/hello_world-s_380692-a8c7015d81a0aa7fb57257e3075a7a9681bdabdb
...                                 ${URI}/hello_world_test-s_380692-a8c7015d81a0aa7fb57257e3075a7a9681bdabdb
...                                 ${URI}/hexdump_test-s_301020-04b414bdc5e445f397b652f239bd1c4d6191df8b
...                                 ${URI}/image_provider_test-s_299776-93e4bd2c0c83d5f257b978cb6fd2f9200cc64a47
...                                 ${URI}/kernel_activations_test-s_323016-8f685520d9aa1490b51d65d950eef2f126c03b81
...                                 ${URI}/kernel_add_n_test-s_317244-5bffe98f7ba5c9b77f9dcaa1562ebeaf552cd75b
...                                 ${URI}/kernel_add_test-s_336504-4ffb874c4d073091405b975092e4071c3ad041b2
...                                 ${URI}/kernel_arg_min_max_test-s_317024-3d5ac3f5863fa17c96851f7bb8b34443fb497e10
...                                 ${URI}/kernel_batch_matmul_test-s_347024-dae052d8d35f24d2120c58958d7ee9204cbcc785
...                                 ${URI}/kernel_batch_to_space_nd_test-s_317080-7d2bb8c53f96c2d8d0b4c68e8311c930d1603ecf
...                                 ${URI}/kernel_broadcast_args_test-s_316096-559d549e2062526828a34defbd4c4361a0211a71
...                                 ${URI}/kernel_broadcast_to_test-s_319160-8bbd7079b79cfe6af59ec7d7c455033dc55a910d
...                                 ${URI}/kernel_cast_test-s_321184-217df4169a11ef9dbb833f18cd82598439f4127a
...                                 ${URI}/kernel_ceil_test-s_311328-c1666757db56137c0b367b6f88c92fb566f9570d
...                                 ${URI}/kernel_circular_buffer_test-s_317504-3d9674656ca23ac0a746d15354cb54ed42bf0159
...                                 ${URI}/kernel_comparisons_test-s_355432-933b7c56371bb1999c80415adb5048334f6f0f9d
...                                 ${URI}/kernel_concatenation_test-s_323580-e48234b9814aa659ced7ecf43e80d61821d64ccb
...                                 ${URI}/kernel_conv_test-s_371464-d8fd8a67b6bffbd28a2c3d0bf504d80dd8f58524
...                                 ${URI}/kernel_cumsum_test-s_324684-7050513e33c0796ec77e028730f4c9ad704c2e0b
...                                 ${URI}/kernel_decode_state_huffman_test-s_353276-a524fe0f15a8d09c6f5397c68a0a08e90b840561
...                                 ${URI}/kernel_decode_state_lut_test-s_354152-f048376d954f5a94ac086b9c3285a6b7bb773942
...                                 ${URI}/kernel_decode_state_prune_test-s_361500-e5e0ceab5dbc504a958cfabeb17b2592f0737208
...                                 ${URI}/kernel_decode_test-s_351580-efd9e87419be92b07b50ba6ec6a929ec86edbb14
...                                 ${URI}/kernel_depth_to_space_test-s_323620-33f7e8d945f8655826bbe56dad2fcab216635ad5
...                                 ${URI}/kernel_depthwise_conv_test-s_358532-4a76920fd7400176b9ea0aefa36ad117eae24366
...                                 ${URI}/kernel_dequantize_test-s_315860-fbd228e4d86cc3db2fdae70ca9fc89bcaacce6e1
...                                 ${URI}/kernel_detection_postprocess_test-s_336656-aaef835ddbcb1cbc52d100f942177d1cb9162c94
...                                 ${URI}/kernel_div_test-s_330148-324fb54e106298701b14e1036be25103f533f176
...                                 ${URI}/kernel_dynamic_update_slice_test-s_322776-07769bb39d6e316864ee343a88df92cbe9350486
...                                 ${URI}/kernel_elementwise_test-s_333572-8de69d59033b1c5dfd8d1d3f8f469d4379034812
...                                 ${URI}/kernel_elu_test-s_316876-31debe06dc22d75ed6f9f1bd8f2b88e8c4206ca9
...                                 ${URI}/kernel_embedding_lookup_test-s_319216-47d697cbcf35fe0252c171a6252fe340eba9adf8
...                                 ${URI}/kernel_exp_test-s_312060-652372019d38646f39305625411062c8925b477e
...                                 ${URI}/kernel_expand_dims_test-s_319732-d10dff971ca25e7208533471a75ec8742dd69d58
...                                 ${URI}/kernel_fill_test-s_318908-1463fe5a4925b1f4527222877de0998acf850291
...                                 ${URI}/kernel_floor_div_test-s_316436-bf92b25642f55b19d291059169f83b1ee7f8ffde
...                                 ${URI}/kernel_floor_mod_test-s_316696-8dac186aaa55b454fce7536bdbd8fffd1afcdaf8
...                                 ${URI}/kernel_floor_test-s_310880-6a85b2135ea74efb8e3dca60bb74bceb08dd6573
...                                 ${URI}/kernel_fully_connected_test-s_344984-fb046e5208354fd817fc872c970065ec500c67ed
...                                 ${URI}/kernel_gather_nd_test-s_320124-33ab5b428b3180abdbbb8f024f70bb575418d151
...                                 ${URI}/kernel_gather_test-s_324360-f139c7c369c72b9aea67fcee8894dc31951800b3
...                                 ${URI}/kernel_hard_swish_test-s_316844-132b0bd7e8794284795dbcf1ca2efd1dfbd47a64
...                                 ${URI}/kernel_l2_pool_2d_test-s_317876-0127fb32ea30d5fca7e9200cabcb8b301e86b843
...                                 ${URI}/kernel_l2norm_test-s_317544-c4dea177c302b45330efdc58e46f6b14934e0b3b
...                                 ${URI}/kernel_leaky_relu_test-s_318584-0e947eb78beee803ab9eb79430b9718d34d41b70
...                                 ${URI}/kernel_log_softmax_test-s_325600-20ba588dbeed02d2935c1a94aabb38e866062999
...                                 ${URI}/kernel_logical_test-s_315740-f8f3010a369597358a47ef0392520235efdd6432
...                                 ${URI}/kernel_logistic_test-s_328096-973a5bed70d5c5ab206c2e6c5c220559c7df5e82
...                                 ${URI}/kernel_lstm_eval_test-s_339708-0b525cff47a61bb967e6ae268c779bcfd7a7584d
...                                 ${URI}/kernel_maximum_minimum_test-s_326272-99e6764e589a2ae349cfe9d2ae7fe942da979771
...                                 ${URI}/kernel_mirror_pad_test-s_318016-4c2b2c10a18c0df5b55fcaba2ec95ceeb2aa6179
...                                 ${URI}/kernel_mul_test-s_330836-420b0906a7ca7958d6fb41791adba73ea5d63bd5
...                                 ${URI}/kernel_neg_test-s_310796-52141ee487649e7ee47d8f87d8d37663e8214c47
...                                 ${URI}/kernel_pack_test-s_317660-e1958e359b7c7e82f34c9bbd2eca0b20f9c47ee4
...                                 ${URI}/kernel_pad_test-s_329624-e6e20b8e6663c5b52e92da1158417043e605691d
...                                 ${URI}/kernel_pooling_test-s_333844-ec0dd444bf30bfb3f7377a33641b93ff3da59638
...                                 ${URI}/kernel_prelu_test-s_317792-1becf9d5f5d9c9c741230cd4973fc99973012302
...                                 ${URI}/kernel_quantization_util_test-s_362172-bb9e70e24b01eda2f7a6183934d6d4a8363441f9
...                                 ${URI}/kernel_quantize_test-s_326660-ee3f0fb4b1e858335b4a506a82d6827cbb99cb53
...                                 ${URI}/kernel_reduce_test-s_349984-06b642c46770c8d97a6f431f3bf01cd54d08220b
...                                 ${URI}/kernel_reshape_test-s_323816-8f1d5ceebb1dc9c8f10e1f00f6043fb5a5cbb41d
...                                 ${URI}/kernel_resize_bilinear_test-s_322036-956c08579aa8eae2965c991408dc1255e2dd9567
...                                 ${URI}/kernel_resize_nearest_neighbor_test-s_324180-a565f21b4194bc4054437c811ea218dbcc4eee9c
...                                 ${URI}/kernel_reverse_test-s_332176-a511b83cec3737fe7d80dc459c1bf9eb72f65f32
...                                 ${URI}/kernel_round_test-s_311404-285b5efcf7468347bc00990a4e6383f0681ccbce
...                                 ${URI}/kernel_select_test-s_324068-ba2544aa9ec437ef5c711787fbfe48836d033473
...                                 ${URI}/kernel_shape_test-s_311512-964d42680bdca01ca4c6a18638f1453e9370dee7
...                                 ${URI}/kernel_signal_delay_test-s_320300-fa25571d072885dae90d4e1915474880bfb7b6c4
...                                 ${URI}/kernel_signal_energy_test-s_317452-f8489326e0633009ee0cfa2e4ba339b0cd4ebe99
...                                 ${URI}/kernel_signal_fft_test-s_383732-c56e2f06d07831e53d17273f4dca6c53b7542cce
...                                 ${URI}/kernel_signal_filter_bank_log_test-s_318052-2f4b4dca644355f6e41f50c32908ae368a88a61e
...                                 ${URI}/kernel_signal_filter_bank_spectral_subtraction_test-s_320704-acc47beceeda1456bd2f5abdbaccd1824f36dec7
...                                 ${URI}/kernel_signal_filter_bank_square_root_test-s_317012-909301bd419b401e0d141b86a05f49383a6d03e7
...                                 ${URI}/kernel_signal_filter_bank_test-s_320248-f85a46e0ee32f5e6cd66d0865547e32184c8a470
...                                 ${URI}/kernel_signal_framer_test-s_320464-348a94c9e069931540809033fa420c6aa83ef27a
...                                 ${URI}/kernel_signal_overlap_add_test-s_325600-2c315a5af6f2fe57ab54f2f891bffab01d92a9c3
...                                 ${URI}/kernel_signal_pcan_test-s_317220-fba58a41f452f4b3a0aef96037e2da683ec34082
...                                 ${URI}/kernel_signal_stacker_test-s_320288-5200c8124a98860f3e6a3697c2a73a5783bb8f10
...                                 ${URI}/kernel_signal_window_test-s_317852-572672d55c93b9dd9cabe00b7b884bf220e34ec8
...                                 ${URI}/kernel_slice_test-s_323092-579294094d20b71a401cecd2df539a7806c7e2f7
...                                 ${URI}/kernel_softmax_test-s_337764-676f5def548eeb7bed1118f7e8cf20a881d78557
...                                 ${URI}/kernel_space_to_batch_nd_test-s_317196-3bb9e2a0207ab8cbca4a764165d261f6170b2bb2
...                                 ${URI}/kernel_space_to_depth_test-s_316768-b623432dc2e65ef0ed26cf1a99d862828297a5c9
...                                 ${URI}/kernel_split_test-s_322608-18255424bd34f07811542c5bf1d1fc6a45e049e5
...                                 ${URI}/kernel_split_v_test-s_321860-4ae74bba409f8d0a3cb85eccf537c58297a03fd6
...                                 ${URI}/kernel_squared_difference_test-s_330868-5df8885b29be9b50800258040db711944d8b2cff
...                                 ${URI}/kernel_squeeze_test-s_316576-ba2db700909f57419f83131bc9ce16655826f393
...                                 ${URI}/kernel_strided_slice_test-s_353584-cc5852cda496e87b225a3a1513127d8a188894f1
...                                 ${URI}/kernel_sub_test-s_336544-3f0819f557f6e8ed54b7022b10e24c229e4f5190
...                                 ${URI}/kernel_svdf_test-s_348464-996deadf6b9054746ea5b04a189441742a2fb4d6
...                                 ${URI}/kernel_tanh_test-s_326328-e85299b5ed32bdaa1fa141fb2495b09766143335
...                                 ${URI}/kernel_transpose_conv_test-s_336876-a22cf6f7a252f1a9b2447e703759bdeaae68c4c7
...                                 ${URI}/kernel_transpose_test-s_329140-f5e4b93a12f4818695b3cf4aa1ad99d9b2bb6f6e
...                                 ${URI}/kernel_unpack_test-s_316360-bf53bdf7e630a6b8de5ff2a44a77dd3dbd89a15a
...                                 ${URI}/kernel_while_test-s_384348-a3d6e76d7e9839a96f6e73b7f61b39298f6e8a86
...                                 ${URI}/kernel_zeros_like_test-s_315512-54fbb675af5652b9ff01f70374007fb5177b31dc
...                                 ${URI}/linear_memory_planner_test-s_303220-f176f2229719b4147fa1ad785f0868b663a93869
...                                 ${URI}/memory_helpers_test-s_318752-a33ef45092af730d5957f349aa7b263d5c4e1d98
...                                 ${URI}/micro_allocation_info_test-s_354388-2d131cf7ef61e8de599af58a7578dff87e77f932
...                                 ${URI}/micro_allocator_test-s_426612-7d5caa50efab9f03b385b701eb8abf05844109d4
...                                 ${URI}/micro_interpreter_context_test-s_357356-f7fa7593994232410811738853ce742b91bc5bb0
...                                 ${URI}/micro_interpreter_graph_test-s_372160-5b9944dbb564a0be0def731ee58810c3a25734c4
...                                 ${URI}/micro_interpreter_test-s_405932-c19ca7f33f761c905c0e687361ec3ac9b873643e
...                                 ${URI}/micro_log_test-s_300524-2435f6294f8ea025cd95642be1aac0fbc2d68828
...                                 ${URI}/micro_mutable_op_resolver_test-s_302060-961bfc783fd1b7ded1e1660f23842a01de707ca7
...                                 ${URI}/micro_resource_variable_test-s_328196-11639bf68b571fbdc9bb37ad5fed56383f2bc7b7
...                                 ${URI}/micro_speech-s_685184-07543b739ff4e950a0d6bac3d580b5ecfd2f66d4
...                                 ${URI}/micro_speech_test-s_685184-07543b739ff4e950a0d6bac3d580b5ecfd2f66d4
...                                 ${URI}/micro_utils_test-s_302292-60fce12b85c9b20d0d4785369a188f2d894774ed
...                                 ${URI}/network_tester_test-s_396896-14d3fdda7e8b7a53e9ef7410e610bb608c5ed14a
...                                 ${URI}/non_persistent_arena_buffer_allocator_test-s_306128-fde957febd667d88298002c12dd5e157c9ff8cd8
...                                 ${URI}/non_persistent_buffer_planner_shim_test-s_303132-ced631b50e0e7c47c611f30398af5dd81e793fac
...                                 ${URI}/persistent_arena_buffer_allocator_test-s_302388-218a3e85223b5435cd7a29458dd1a388e4b86dca
...                                 ${URI}/person_detection_test-s_848156-0c5abfde0df8ce751c15f67f2294bc2f9233f469
...                                 ${URI}/recording_single_arena_buffer_allocator_test-s_306980-2c064ce44d43651cf3c72ff068d999d55c8a2cac
...                                 ${URI}/single_arena_buffer_allocator_test-s_312164-96758de2caa1d233fca3e57d5a79012df909d2cb
...                                 ${URI}/span_test-s_300404-033b81a9abbabcef0468fa48ef3483effef3b1f5
...                                 ${URI}/static_vector_test-s_302664-7061f659486570e540424f94b8526f459b58e61d
...                                 ${URI}/testing_helpers_test-s_304204-64ce19fc12cd3d49f65253c4e16c6ae20db6ae8a
...                                 ${URI}/unidirectional_sequence_lstm_test-s_351900-726ce4ee701a27b11ed9f03f6a1dcd18745f0a40

${REPL}                             SEPARATOR=\n
...                                 """
...                                 cpu: CPU.CortexM @ sysbus { cpuType: "cortex-m85"; nvic: nvic }
...                                 nvic: IRQControllers.NVIC @ sysbus 0xE000E000 { -> cpu@0 }
...                                 rom: Memory.MappedMemory @ sysbus 0x0 { size: 0x20000000 }
...                                 sram: Memory.MappedMemory @ sysbus 0x20000000 { size: 0x20000000 }
...                                 ram: Memory.MappedMemory @ sysbus 0x60000000 { size: 0x20000000 }
...                                 serial: UART.TrivialUart @ sysbus 0xA8000000
...                                 serial2: UART.CMSDK_APB_UART @ sysbus 0x49303000
...                                 """

*** Keywords ***
Create Machine
    [Arguments]                     ${ELF}
    ...                             ${tester}=sysbus.serial

    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL}
    Execute Command                 sysbus LoadELF ${ELF}

    Create Terminal Tester          ${tester}

*** Test Cases ***
Should Pass Matrix Test
    Create Machine                  ${MATRIX_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Pass FIR Test
    Create Machine                  ${FIR_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Generate Expected Values In Bayes Test
    Create Machine                  ${BAYES_ELF}
    Start Emulation

    Wait For Line On Uart           0
    Wait For Line On Uart           1
    Wait For Line On Uart           2

Should Generate Expected Values In Class Marks Test
    Create Machine                  ${CLASS_MARKS_ELF}
    Start Emulation

    Wait For Line On Uart           mean = 212.300003, std = 50.912827

Should Pass Variance Test
    Create Machine                  ${VARIANCE_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Generate Expected Values In SVM Test
    Create Machine                  ${SVM_ELF}
    Start Emulation

    Wait For Line On Uart           Result = 0
    Wait For Line On Uart           Result = 1

Should Pass Sin Cos Test
    Create Machine                  ${SIN_COS_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Pass Signal Convergence Test
    Create Machine                  ${SIGNAL_CONVERGENCE_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Pass Linear Interpolation Test
    Create Machine                  ${LINEAR_INTERP_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Pass Dot Product Test
    Create Machine                  ${DOTPRODUCT_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Pass Arm Convolution Test
    Create Machine                  ${CONVOLUTION_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Pass Fft Bin Test
    Create Machine                  ${FFT_BIN_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Pass Graphic Equalizer Test
    Create Machine                  ${GRAPHIC_EQUALIZER_ELF}
    Start Emulation

    Wait For Line On Uart           SUCCESS

Should Run CMSIS-NN Tests
    FOR  ${elf}  IN  @{CMSIS-NN_ELFS}
        Create Machine                  ${elf}  sysbus.serial2
        Log To Console                  Running test: ${elf}

        Wait For Line On Uart           ~~~ALL TESTS PASSED~~~
        Reset Emulation
    END
