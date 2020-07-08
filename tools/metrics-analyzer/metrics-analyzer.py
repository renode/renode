import argparse
import matplotlib.pyplot as plt
from assets.instructions import *
from assets.memory import *
from assets.peripherals import *
from assets.exceptions import *


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


def generate_report(options):
    show_executed_instructions(options, onePlotFigureSize, fontSize)
    show_memory_access(options, onePlotFigureSize, fontSize)
    show_peripheral_access(options, twoPlotFigureSize, fontSize)
    show_exceptions(options, onePlotFigureSize, fontSize)


options = prepare_parser().parse_args()
generate_report(options)
if not options.no_dialogs:
    plt.show()