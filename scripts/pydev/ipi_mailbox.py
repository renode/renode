# This PMU implementation is based on open source firmware available at:
# https://github.com/Xilinx/embeddedsw/tree/master/lib/sw_apps/zynqmp_pmufw

from Antmicro.Renode.Peripherals.CPU import RegisterValue

local_request_region_offset = 0x0
local_response_region_offset = 0x20
remote_request_region_offset = 0x8c0
remote_response_region_offset = 0x8e0

arg_size = 0x4
arg_count = (local_response_region_offset - local_request_region_offset) // arg_size

pmu_functions = []

PM_API_MAX = 0x4A

XST_SUCCESS = 0x0
XST_INVALID_PARAM = 0xF

CRL_APB_UART1_REF_CTRL = 0x01001800

PM_CLOCK_IOPLL = 0
PM_CLOCK_UART1_REF = 57

PM_CLOCK_DIV0_ID = 0
PM_CLOCK_DIV1_ID = 1

PM_DIV0_SHIFT = 8
PM_DIV1_SHIFT = 16

PM_DIV_MASK = 0x3F

NODE_APLL = 50
NODE_VPLL = 51
NODE_DPLL = 52
NODE_RPLL = 53
NODE_IOPLL = 54

PM_PLL_PARAM_DIV2 = 0
PM_PLL_PARAM_FBDIV = 1
PM_PLL_PARAM_PRE_SRC = 3
PM_PLL_PARAM_POST_SRC = 4

for pmu_index in range(PM_API_MAX + 1):
    pmu_functions.append({"implemented": False})

pmu_functions[0x1] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_GET_API_VERSION",
    "local_mapping_function": lambda request_args: [XST_SUCCESS, 0x10001],
}

pmu_functions[0x2] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_SET_CONFIGURATION",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0xd] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_REQUEST_NODE",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0xe] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_RELEASE_NODE",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0xf] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_SET_REQUIREMENT",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}


# Reset functionality is just a simple key value storage which on PM_RESET_GET_STATUS
# returns value previously set on PM_RESET_ASSERT for given reset value
def pmResetAssert(request_args):
    reset = request_args[0]
    action = request_args[1]

    reset_statuses[str(reset)] = action

    return [XST_SUCCESS]


pmu_functions[0x11] = {
    "implemented": True,
    "ignored": True,
    "name": "PM_RESET_ASSERT",
    "local_mapping_function": pmResetAssert,
}


# Reset functionality is just a simple key value storage which on PM_RESET_GET_STATUS
# returns value previously set on PM_RESET_ASSERT for given reset value
def pmResetGetStatus(request_args):
    reset = request_args[0]
    action = 0

    if str(reset) in reset_statuses:
        action = reset_statuses[str(reset)]

    return [XST_SUCCESS, action]


pmu_functions[0x12] = {
    "implemented": True,
    "ignored": True,
    "name": "PM_RESET_GET_STATUS",
    "local_mapping_function": pmResetGetStatus,
}

pmu_functions[0x13] = {
    "implemented": True,
    "ignored": True,
    "name": "PM_MMIO_WRITE",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x14] = {
    "implemented": True,
    "ignored": True,
    "name": "PM_MMIO_READ",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x15] = {
    "implemented": True,
    "ignored": True,
    "name": "PM_INIT_FINALIZE",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x17] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_FPGA_GET_STATUS",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x18] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_GET_CHIPID",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x1c] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_PINCTRL_REQUEST",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x1d] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_PINCTRL_RELEASE",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x1f] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_PINCTRL_SET_FUNCTION",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x20] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_PINCTRL_CONFIG_PARAM_GET",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x21] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_PINCTRL_CONFIG_PARAM_SET",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x24] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_CLOCK_ENABLE",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x25] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_CLOCK_DISABLE",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x26] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_CLOCK_GETSTATE",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x27] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_CLOCK_SETDIVIDER",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}


# Those values are retrieved by cross referencing PMU FW source with
# reset values of clocks registers available at:
# https://www.xilinx.com/htmldocs/registers/ug1087/ug1087-zynq-ultrascale-registers.html
def pmClockGetDivider(request_args):
    clockId = request_args[0]
    divId = request_args[1]

    if clockId == PM_CLOCK_UART1_REF:
        shift = 0

        if divId == PM_CLOCK_DIV0_ID:
            shift = PM_DIV0_SHIFT
        elif divId == PM_CLOCK_DIV1_ID:
            shift = PM_DIV1_SHIFT
        else:
            return [XST_INVALID_PARAM]

        divider = (CRL_APB_UART1_REF_CTRL >> shift) & PM_DIV_MASK

        return [XST_SUCCESS, divider]
    else:
        return [XST_SUCCESS]


pmu_functions[0x28] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_CLOCK_GETDIVIDER",
    "local_mapping_function": pmClockGetDivider,
}


# Those values are retrieved by cross referencing PMU FW source with
# reset values of clocks registers available at:
# https://www.xilinx.com/htmldocs/registers/ug1087/ug1087-zynq-ultrascale-registers.html
def pmClockGetParent(request_args):
    clockId = request_args[0]

    if clockId == PM_CLOCK_UART1_REF:
        return [XST_SUCCESS, 0x0]
    else:
        return [XST_SUCCESS]


pmu_functions[0x2c] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_CLOCK_GETPARENT",
    "local_mapping_function": pmClockGetParent,
}


# Those values are retrieved by cross referencing PMU FW source with
# reset values of clocks registers available at:
# https://www.xilinx.com/htmldocs/registers/ug1087/ug1087-zynq-ultrascale-registers.html
def mapPllIdToResetValue(pllId):
    if pllId == NODE_APLL:
        return 0x00012C09
    elif pllId == NODE_VPLL:
        return 0x00012809
    elif pllId == NODE_DPLL:
        return 0x00002C09
    elif pllId == NODE_RPLL:
        return 0x00012C09
    elif pllId == NODE_IOPLL:
        return 0x00012C09
    else:
        return 0x0


# Those values are retrieved by cross referencing PMU FW source with
# reset values of clocks registers available at:
# https://www.xilinx.com/htmldocs/registers/ug1087/ug1087-zynq-ultrascale-registers.html
def mapParamIdToShift(paramId):
    if paramId == PM_PLL_PARAM_DIV2:
        return 16
    elif paramId == PM_PLL_PARAM_FBDIV:
        return 8
    elif paramId == PM_PLL_PARAM_PRE_SRC:
        return 20
    elif paramId == PM_PLL_PARAM_POST_SRC:
        return 24
    else:
        return 0


# Those values are retrieved by cross referencing PMU FW source with
# reset values of clocks registers available at:
# https://www.xilinx.com/htmldocs/registers/ug1087/ug1087-zynq-ultrascale-registers.html
def mapParamIdToMask(paramId):
    if paramId == PM_PLL_PARAM_DIV2:
        return 0x1
    elif paramId == PM_PLL_PARAM_FBDIV:
        return 0x7F
    elif paramId == PM_PLL_PARAM_PRE_SRC:
        return 0x7
    elif paramId == PM_PLL_PARAM_POST_SRC:
        return 0x7
    else:
        return 0x0


# Those values are retrieved by cross referencing PMU FW source with
# reset values of clocks registers available at:
# https://www.xilinx.com/htmldocs/registers/ug1087/ug1087-zynq-ultrascale-registers.html
def pmPllGetParam(request_args):
    pllId = request_args[0]
    paramId = request_args[1]

    resetValue = mapPllIdToResetValue(pllId)
    shift = mapParamIdToShift(paramId)
    mask = mapParamIdToMask(paramId)

    paramValue = (resetValue >> shift) & mask

    self.DebugLog("PM_PLL_GET_PARAM with pllId=%d, paramId=%d, paramValue=0x%x" % (pllId, paramId, paramValue))

    return [XST_SUCCESS, paramValue]


pmu_functions[0x31] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_PLL_GET_PARAM",
    "local_mapping_function": pmPllGetParam,
}

pmu_functions[0x32] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_PLL_SET_MODE",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x33] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_PLL_GET_MODE",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x3f] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_FEATURE_CHECK",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x48] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_FPGA_GET_VERSION",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

pmu_functions[0x49] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_FPGA_GET_FEATURE_LIST",
    "local_mapping_function": lambda request_args: [XST_SUCCESS],
}

def wakeupCpu(request_args):
    self.Log(LogLevel.Debug, 'PM_REQUEST_WAKEUP, id={0}', request_args[0])

    # `zynqmp_pm_defs.h` from Xilinx's Arm Trusted Firmware fork (`plat/xilinx/zynqmp`)
    pm_node_id_to_cpuId = {
        2: 0, # 'NODE_APU_0'
        3: 1, # 'NODE_APU_1'
        4: 2, # 'NODE_APU_2'
        5: 3, # 'NODE_APU_3'
    }

    pm_node_id = request_args[0]
    if pm_node_id not in pm_node_id_to_cpuId:
        self.Log(LogLevel.Debug, 'PM_REQUEST_WAKEUP received, but not for APU. Ignoring.')
        return [XST_INVALID_PARAM]

    # Filter only APU nodes
    _cpus = filter(lambda cpu: str(type(cpu)) == "<type 'ARMv8A'>", emulationManager.Instance.CurrentEmulation.Machines[0].SystemBus.GetCPUs())
    cpus = {cpu.Id: cpu for cpu in _cpus}

    apu_id = pm_node_id_to_cpuId[pm_node_id]
    if apu_id not in cpus:
        self.Log(LogLevel.Error, 'PM_REQUEST_WAKEUP received, but cpuId is unrecognized. The platform might be misconfigured.')
        return [XST_INVALID_PARAM]

    address = (request_args[2] << 32) | request_args[1]

    # First bit is used to signify that a new address will be set
    if(address & 1):
        cpus[apu_id].PC = RegisterValue.Create(address & ~1, 64)
        cpus[apu_id].IsHalted = False

    self.Log(LogLevel.Debug, 'Updated CPU, cpuId={0}, addr={1}', apu_id, hex(address))

    return [XST_SUCCESS]

pmu_functions[0xA] = {
    "implemented": True,
    "ignored": False,
    "name": "PM_REQUEST_WAKEUP",
    "local_mapping_function": wakeupCpu,
}

def check_request_from_args_local():
    return pmu_functions[request_args_local[0]]["implemented"]


def create_reponse_from_args_local():
    for arg_index in range(1, arg_count):
        response_args_local[arg_index] = 0x0

    pmu_function = pmu_functions[request_args_local[0]]

    if pmu_function["implemented"]:
        response_args = pmu_function["local_mapping_function"](request_args_local[1:])

        for arg_index in range(len(response_args)):
            response_args_local[arg_index] = response_args[arg_index]

        if not pmu_function["ignored"]:
            self.DebugLog("%s invoked" % (pmu_function["name"]))

        return True
    else:
        return False


if request.isInit:
    request_args_local = [0] * arg_count
    response_args_local = [0] * arg_count
    reset_statuses = {}
if request.isRead:
    if request.offset < remote_response_region_offset:
        arg_offset = request.offset - local_response_region_offset
        arg_index = arg_offset / arg_size

        if not create_reponse_from_args_local():
            self.DebugLog("Local read access (offset: 0x%x, value: 0x%x)" % (arg_offset, response_args_local[arg_index]))

        request.value = response_args_local[arg_index]
elif request.isWrite:
    if request.offset < remote_request_region_offset:
        arg_offset = request.offset - local_request_region_offset
        arg_index = arg_offset / arg_size

        request_args_local[arg_index] = request.value

        if not check_request_from_args_local():
            self.DebugLog("Local write access (offset: 0x%x, value: 0x%x)" % (arg_offset, request_args_local[arg_index]))
