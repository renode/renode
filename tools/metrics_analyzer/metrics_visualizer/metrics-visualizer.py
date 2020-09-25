#!/usr/bin/env python3

import argparse
import matplotlib.pyplot as plt

from assets.instructions import *
from assets.memory import *
from assets.peripherals import *
from assets.exceptions import *


import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from metrics_parser import MetricsParser

onePlotFigureSize = [10.4,5.2]
twoPlotFigureSize = [10.4,10.4]
fontSize = 16


def prepare_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument(dest='filePath', help='Set path to log file')
    parser.add_argument('--no-dialogs', help='Images output only', action='store_true')
    parser.add_argument('--real-time', help='Use real-time to represent the graphs', action='store_true')
    parser.add_argument('-o', '--output', dest='output', action='store', default=None, help='Output directory for artifacts')
    return parser


def generate_report(metricsParser, options):
    show_executed_instructions(metricsParser, options, onePlotFigureSize, fontSize)
    show_memory_access(metricsParser, options, onePlotFigureSize, fontSize)
    show_peripheral_access(metricsParser, options, twoPlotFigureSize, fontSize)
    show_exceptions(metricsParser, options, onePlotFigureSize, fontSize)


options = prepare_parser().parse_args()
metricsParser = MetricsParser(options.filePath)
generate_report(metricsParser, options)
if not options.no_dialogs:
    plt.show()