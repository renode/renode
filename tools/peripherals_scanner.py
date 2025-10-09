#!/usr/bin/python
# pylint: disable=line-too-long, C0325, missing-docstring
import os
import re
import json
import argparse
import fnmatch
import logging
from collections import Counter


logging.basicConfig(level=logging.INFO)


# parameters
URI_PREFIX = "https://github.com/renode/renode/tree/master/"
PERIPHERALS_URI_PREFIX = "https://github.com/renode/renode-infrastructure/tree/master/"
PERIPHERAL_LINE_PATTERN = r'^[A-Za-z0-9_]+\s*:\s*([^\s]+)\s*@'
USING_LINE_PATTERN = r'^using "([.A-Za-z0-9_/-]+)"'
TOP_DIR = None

GROUPS = []
PLATFORMS = []
PERIPHERALS = []
CATEGORIES = []


def get_or_create_platform(path):
    for p in PLATFORMS:
        if p._path == path:
            return p

    p = Platform(path)
    PLATFORMS.append(p)

    return p


def get_or_create_peripheral(kind_name, class_name):
    p = Peripheral(kind_name, class_name)
    return p


def try_get_category(platform):
    mapping = {
        "A2_CV32E40P": "OHG",
        "a20": "ALLWINNER",
        "ambiq-apollo4": "AMBIQ",
        "arduino_101-shield":  "NRF",
        "arduino_nano_33_ble": "NRF",
        "arty_litex_vexriscv": "LITEX",
        "arvsom":  "STARFIVE",
        "at91rm9200":  "MICROCHIP",
        "atsamd21j17d-aft": "MICROCHIP",
        "atsamd51g19a": "MICROCHIP",
        "beaglev-fire": "PFSOC",
        "beaglev_starlight":   "STARFIVE",
        "brd4116a":    "EFM",
        "brd4117a":    "EFM",
        "brd4118a":    "EFM",
        "brd4120a":    "EFM",
        "brd4121a":    "EFM",
        "brd4162a":    "EFM",
        "brd4186c":    "EFM",
        "brd4402a":    "EFM",
        "cc2538":  "TI",
        "colibri-vf61":    "NXP I.MX",
        "core-v-mcu":  "OHG",
        "cortex-a53": "GENERIC ARM",
        "cortex-a53-gicv2": "GENERIC ARM",
        "cortex-a53-gicv3": "GENERIC ARM",
        "cortex-a53-gicv3_smp": "GENERIC ARM",
        "cortex_a53_virtio": "GENERIC ARM",
        "cortex-a78": "GENERIC ARM",
        "cortex-r52": "GENERIC ARM",
        "cortex-r52_smp": "GENERIC ARM",
        "cortex-r52_smp_4": "GENERIC ARM",
        "cortex-r8": "GENERIC ARM",
        "crosslink-nx-evn":    "LITEX",
        "efm32g210":   "EFM",
        "efm32g222":   "EFM",
        "efm32g232":   "EFM",
        "efm32g842":   "EFM",
        "efm32g890":   "EFM",
        "efm32gg942":  "EFM",
        "efm32gg995":  "EFM",
        "efm32hg350":  "EFM",
        "efm32jg1":    "EFM",
        "efm32jg12":   "EFM",
        "efm32lg942":  "EFM",
        "efm32lg995":  "EFM",
        "efm32pg1":    "EFM",
        "efm32pg12":   "EFM",
        "efm32tg840":  "EFM",
        "efm32wg995":  "EFM",
        "efm32zg222":  "EFM",
        "efr32mg1":    "EFM",
        "efr32mg12":   "EFM",
        "efr32mg13":   "EFM",
        "efr32mg24":   "EFM",
        "efr32mg26":   "EFM",
        "efr32xg22":   "EFM",
        "eos-s3":  "EOS",
        "eos-s3-qomu": "EOS",
        "eos-s3-quickfeather": "EOS",
        "ezr32hg320":  "EFM",
        "ezr32lg330":  "EFM",
        "ezr32wg330":  "EMF",
        "fomu":    "LITEX",
        "fsl_lx2160ardb": "NXP LAYERSCAPE",
        "gr716":   "GAISLER",
        "gr716-devboard": "GAISLER",
        "gr712rc": "GAISLER",
        "x86":     "X86",
        "ice40up5k-mdp-evn":   "LITEX",
        "imxrt1064":   "NXP I.MX",
        "imxrt500":    "NXP I.MX",
        "kendryte_k210":   "KENDRYTE",
        "leon3":   "GAISLER",
        "leon3-externals": "GAISLER",
        "litex_common":    "LITEX",
        "litex_ibex":  "LITEX",
        "litex_linux_vexriscv_sdcard": "LITEX",
        "litex_microwatt": "LITEX",
        "litex_minerva":   "LITEX",
        "litex_nexys_video_vexriscv_linux":  "LITEX",
        "litex_picorv32":  "LITEX",
        "litex_tock":  "LITEX",
        "litex_vexriscv":  "LITEX",
        "litex_vexriscv_linux":    "LITEX",
        "litex_vexriscv_micropython":  "LITEX",
        "litex_vexriscv_smp":  "LITEX",
        "litex_vexriscv_tftp": "LITEX",
        "litex_vexriscv_verilated_cfu":    "LITEX",
        "litex_vexriscv_verilated_liteuart":   "LITEX",
        "litex_vexriscv_zephyr":   "LITEX",
        "litex_zephyr_vexriscv_i2s":   "LITEX",
        "lpc2294":  "NXP LPC",
        "mars_zx3":    "ZYNQ",
        "mars_zx3-externals":  "ZYNQ",
        "max32652": "MAXIM",
        "max32652-evkit": "MAXIM",
        "microwatt":   "POWERPC",
        "mimxrt1064_evk":   "NXP I.MX",
        "miv": "MIV",
        "miv_rv32": "MIV",
        "miv-board":   "MIV",
        "miv-board-additional-uarts":  "MIV",
        "mpc5567": "NXP PPC",
        "mpfs-icicle-kit": "PFSOC",
        "msp430f2619": "MSP430",
        "murax_vexriscv":  "OTHER RISC-V",
        "murax_vexriscv_verilated_uart":   "OTHER RISC-V",
        "nrf52840":    "NORDIC",
        "nrf52840dk_nrf52840":    "NORDIC",
        "nucleo_wba52cg": "STM",
        "nucleo_h753zi": "STM",
        "nxp-k6xf":    "NXP KINETIS",
        "opentitan-earlgrey":  "OTHER RISC-V",
        "opentitan-earlgrey-cw310":  "OTHER RISC-V",
        "picosoc": "OTHER RISC-V",
        "polarfire-soc":   "PFSOC",
        "quark-c1000": "X86",
        "quark_c1000-cc2520":  "X86",
        "acrn_x86_64": "X86-64",
        "up_squared_x86_64": "X86-64",
        "renesas_rz_t2m": "RENESAS",
        "renesas_rz_t2m_rsk": "RENESAS",
        "renesas_rz_g2l": "RENESAS",
        "ri5cy":   "OTHER RISC-V",
        "riscv_verilated_uartlite":    "OTHER RISC-V",
        "riscv_virt":   "OTHER RISC-V",
        "s32k118": "NXP S32K",
        "nxp-s32k388": "NXP S32K",
        "sam_e70": "MICROCHIP",
        "sam4s": "MICROCHIP",
        "sam4s8b": "MICROCHIP",
        "sam4s16c": "MICROCHIP",
        "sam4s_xplained": "MICROCHIP",
        "sifive-fe310":    "SIFIVE",
        "sifive-fu540":    "SIFIVE",
        "sifive-fu740":    "SIFIVE",
        "sltb001a":    "EFM",
        "sltb004a":    "EFM",
        "slwstk6220a": "EFM",
        "starfive-jh7100": "STARFIVE",
        "stk3200": "EFM",
        "stk3600": "EFM",
        "stk3700": "EFM",
        "stk3800": "EFM",
        "stm32f0": "STM",
        "stm32f042": "STM",
        "stm32f072":   "STM",
        "stm32f072b_discovery":    "STM",
        "stm32f103":   "STM",
        "stm32f4": "STM",
        "stm32f412": "STM",
        "stm32f429":   "STM",
        "stm32f4_discovery":   "STM",
        "stm32f4_discovery-additional_gpios":  "STM",
        "stm32f4_discovery-bb":    "STM",
        "stm32f4_discovery-kit":   "STM",
        "stm32f746":   "STM",
        "stm32f7_discovery-bb":    "STM",
        "stm32g0":      "STM",
        "stm32h753":    "STM",
        "stm32h743":    "STM",
        "stm32l071": "STM",
        "stm32l072": "STM",
        "stm32l151":   "STM",
        "stm32l552": "STM",
        "stm32w108":   "STM",
        "stm32wba52": "STM",
        "tegra2":  "TEGRA",
        "tegra3":  "TEGRA",
        "tegra_externals": "TEGRA",
        "tock_veer_el2_sim": "OTHER RISC-V",
        "ut32m0r500": "GAISLER",
        "verilated_ibex": "LITEX",
        "versatile":   "GENERIC ARM",
        "vexpress":    "GENERIC ARM",
        "vexpress-externals":  "GENERIC ARM",
        "vybrid":  "NXP I.MX",
        "xtensa-sample-controller": "XTENSA",
        "zedboard":    "ZYNQ",
        "zedboard-externals":  "ZYNQ",
        "zolertia-firefly":    "ZYNQ",
        "xilinx_zynqmp_r5":  "ZYNQ",
        "zynq-7000":   "ZYNQ",
        "zynqmp":   "ZYNQ",
        "zynqmp-zcu102-revA":   "ZYNQ",
        "zynqmp-zcu102-revB":   "ZYNQ",
        "zynqmp-zcu104":   "ZYNQ",
        "cortex-a9_smp": "GENERIC ARM",
        "cortex-a9": "GENERIC ARM",
        "cortex-r8_smp": "GENERIC ARM",
        "cortex-r8": "GENERIC ARM",
        "nuvoton_npcx9": "NUVOTON",
        "nuvoton_npcx9m6fb_evb": "NUVOTON",
        "andes_ae350_n25": "ANDES",
        "renesas-r7fa8m1a": "RENESAS",
        "renesas-r7fa2l1a": "RENESAS",
        "renesas-r7fa2e1a9": "RENESAS",
        "renesas-r7fa6m5b": "RENESAS",
        "renesas-r7fa4m1a": "RENESAS",
        "ck-ra6m5": "RENESAS",
        "renesas-da14592": "RENESAS",
        "ek-ra2e1": "RENESAS",
        "ek-ra8m1": "RENESAS",
        "arduino_uno_r4_minima": "RENESAS",
        "renesas_ck_ra6m5_sensors_example": "RENESAS",
        "renesas-ck_ra6m5": "RENESAS",
        "renesas-ek_ra2e1": "RENESAS",
        "renesas-ek_ra8m1": "RENESAS",
        "renesas-rz_t2m_rsk": "RENESAS",
        "vegaboard_ri5cy": "OTHER RISC-V",
        "x86-kvm": "X86",
        "x86_64-kvm": "X86-64",
    }

    if platform.get_name() not in mapping:
        raise Exception("don't know category for: {} ({})".format(platform.get_name(), platform._path))

    result = mapping[platform.get_name()]
    if result not in CATEGORIES:
        CATEGORIES.append(result)
    return result


class Platform:
    def __init__(self, path):
        self._path = path
        self._peripherals = []
        self._usings = []
        self._cached_res = None
        self._category = try_get_category(self)

        self._parse()

    def get_name(self):
        return os.path.splitext(os.path.basename(self._path))[0]

    def get_path(self):
        return self._path

    def get_peripherals(self):
        if self._cached_res:
            return self._cached_res

        res = {}

        for u in self._usings:
            ps = u.get_peripherals()
            for k in ps:
                if k not in res:
                    res[k] = ps[k]
                else:
                    res[k].extend(ps[k])

        for p in self._peripherals:
            if p._kind not in res:
                res[p._kind] = [p._type]
            else:
                res[p._kind].append(p._type)

        self._cached_res = res
        return res

    def get_all_peripherals(self):
        # if self._cached_res:
        #     return self._cached_res

        res = []

        for u in self._usings:
            ps = u.get_all_peripherals()
            for k in ps:
                found = False
                for x in res:
                    if x == k:
                        x._count += 1
                        found = True
                        break
                if not found:
                    res.append(k)

        for k in self._peripherals:
            found = False
            for x in res:
                if x == k:
                    x._count += 1
                    found = True
                    break
            if not found:
                res.append(k)

        # self._cached_res = res
        return res

    def _parse(self):
        with open(self._path, 'r') as f:
            for line in f.readlines():
                # maybe it's a using statement
                m = re.search(USING_LINE_PATTERN, line)
                if m:
                    match = m.group(1)
                    if match.startswith('.'):
                        path = os.path.join(os.path.dirname(self._path), match)
                    else:
                        path = os.path.join(TOP_DIR, match)
                    self._usings.append(get_or_create_platform(path))
                    continue

                # maybe it's a peripheral definition
                p = Peripheral.try_parse(line)
                if p:
                    added = False
                    for xp in self._peripherals:
                        if xp == p:
                            xp._count += 1
                            added = True
                            break

                    if not added:
                        self._peripherals.append(p)

                    continue

    def __str__(self):
        res = "[PLATFORM: {}]".format(self._path)
        for u in self._usings:
            res += "\n  [USING: {}]".format(u)
        for p in self._peripherals:
            res += "\n  {}".format(p)
        return res


class Peripheral:
    def __init__(self, kind, type):
        self._kind = kind
        self._type = type
        self._count = 1

        path = find_file(TOP_DIR + '/src/Infrastructure', self._type + '.cs')
        self._uri = '{}{}'.format(PERIPHERALS_URI_PREFIX, path)

    @staticmethod
    def try_parse(line):
        m = re.search(PERIPHERAL_LINE_PATTERN, line)
        if not m:
            return None

        type_name = m.group(1)
        # put all peripherals without a namespace into 'Others'
        if '.' not in type_name:
            type_name = "Others." + type_name

        kind_name, class_name = type_name.split('.', 1)

        return get_or_create_peripheral(kind_name, class_name)

    def __str__(self):
        res = "[PERIPHERAL: {} / {}]".format(self._kind, self._type)
        return res

    def __hash__(self):
        return hash(self._kind + self._type)

    def __eq__(self, other):
        return self._kind == other._kind and self._type == other._type


def find_file(root_folder, fname):
    for _root, _, _filenames in os.walk(root_folder):
        if fname in _filenames:
            return os.path.join(_root[len(root_folder) + 1:], fname)
    return None



def scan(folder):
    # scan for json files
    for root, dirnames, filenames in os.walk(folder):
        for filename in fnmatch.filter(filenames, '*.repl'):
            if 'fomu_led' in filename:
                continue
            platform = get_or_create_platform(os.path.join(root, filename))

            for kind in platform.get_peripherals():
                if kind not in GROUPS:
                    GROUPS.append(kind)


def generate_json():
    return json.dumps(PLATFORMS, default=lambda x: {i:x.__dict__[i] for i in x.__dict__ if i != '_cached_res'}, indent=4, sort_keys=True)


def platform_to_html(platform):
    res = ''

    res += '    <h4 onclick="{1}">{0}</h4>\n'.format(platform.get_name(), "showPeripherals(this, '{}')".format(platform.get_name()))

    return res

def platform_peripherals_table(platform):
    res = ''

    res += '<table class="boards-table docutils align-default" style="margin-top: 10px">\n'
    res += '<tr>\n'
    res += '<th>kind</td>\n'
    res += '<th>type</td>\n'
    res += '</tr>\n'
    for peripheral in platform.get_all_peripherals():
        res += '<tr>\n'
        res += '<td>{}</td>\n'.format(peripheral._kind)
        res += '<td><a href="{}">{}</a>{}</td>\n'.format(peripheral._uri, peripheral._type, ' (x{})'.format(peripheral._count) if peripheral._count > 1 else '')
        res += '</tr>\n'
    res += '</table>\n'

    return res

def generate_html():
    res = ''

    res +="""
<style>
.category h3 {
  background-color: #666;
  border: none;
  // color: #404040;
  padding: 10px 20px;
  text-align: center;
  text-decoration: none;
  display: inline-block;
  margin: 4px 2px;
  cursor: pointer;
  border-radius: 16px;
}

.platform h4 {
  background-color: white;
  border: solid 1px;
  border-color: #007ded;
  color: #007ded;
  padding: 10px 20px;
  text-align: center;
  text-decoration: none;
  display: inline-block;
  margin: 4px 2px;
  cursor: pointer;
  border-radius: 16px;
}

.platform_selected h4 {
  background-color: #007ded;
  border: solid 1px;
  border-color: #007ded;
  color: white;
  padding: 10px 20px;
  text-align: center;
  text-decoration: none;
  display: inline-block;
  margin: 4px 2px;
  cursor: pointer;
  border-radius: 16px;
}

div.category {
    display: inline-block;
}

div.platform {
    display: none;
}

</style>
"""

    PLATFORMS.sort(key=lambda x: x.get_name())
    res += '<div style="margin-top: 10px; margin-bottom: 10px">\n'
    for category in sorted(CATEGORIES):
        res += '<div class="category">\n'.format(category)
        res += '  <h3 onclick="toggleCategory(this)">{}</h3>\n'.format(category)
        for platform in [x for x in PLATFORMS if x._category == category]:
            res += '  <div class="platform">\n'.format(platform_to_html(platform))
            res += platform_to_html(platform)
            res += '  </div>\n'
        res += '</div>\n'
    res += '</div>\n'

    for platform in PLATFORMS:
        res += '  <div id="peripherals-{}" class="peripherals-table" style="display: none">\n'.format(platform.get_name())
        res += platform_peripherals_table(platform)
        res += '  </div>\n'

    res +="""
<script>

function hideAllPeripherals () {
    var kids = document.getElementsByClassName('peripherals-table');
    for (kid of kids) {
        kid.style.display = "none";
    }

    var kids = document.getElementsByClassName('platform_selected');
    for (kid of kids) {
        kid.className = "platform";
    }
}

function showPeripherals (target, name) {
    hideAllPeripherals();

    target.parentElement.className = 'platform_selected';

    var targetDiv = document.getElementById('peripherals-' + name);
    targetDiv.style.display = '';
}

function toogleElementsByClass (element, className) {
    var kids = element.getElementsByClassName(className);
    for (kid of kids) {
        if(kid.style.display == "none" || kid.style.display == "")
            kid.style.display = "inline-block";
        else
            kid.style.display = "none";
    }
}

function toggleCategory (element) {
    hideAllPeripherals();
    toogleElementsByClass(element.parentElement, "platform");
}

</script>

"""

    return res

def main():
    global TOP_DIR

    parser = argparse.ArgumentParser()

    parser.add_argument("-d", "--dir", dest="dir", action="store", default=".", help="Directory to scan")
    parser.add_argument("-J", "--json", dest="generate_json", action="store_true", default=False, help="Generate JSON output")
    parser.add_argument("-H", "--html", dest="generate_html", action="store_true", default=False, help="Generate HTML output")

    options = parser.parse_args()
    flag = False

    TOP_DIR = options.dir
    scan(options.dir + '/platforms')

    if options.generate_json:
        flag = True
        print(generate_json())

    if options.generate_html:
        flag = True
        print(generate_html())

    if not flag:
        parser.print_help()

main()
