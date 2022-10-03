import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import pandas as pd

from .legend_picker import *
from .helpers import *


def show_executed_instructions(metricsParser, options, onePlotFigureSize, fontSize):
    cpus, instructionEntries = metricsParser.get_instructions_entries()
    fig, ax = plt.subplots(figsize=onePlotFigureSize, constrained_layout=True)

    instructionLines = _prepare_data(fig, ax, cpus, instructionEntries, 'realTime' if options.real_time else 'virtualTime')

    handles, labels = ax.get_legend_handles_labels()
    legend = fig.legend(handles, labels, loc='upper left')

    fig.suptitle('Executed instructions', fontsize=fontSize)
    ax.set_xlabel('{} time [ms]'.format('Real' if options.real_time else 'Virtual'))
    ax.set_ylabel('Number of instructions')

    set_legend_picker(fig, instructionLines, legend)
    
    save_fig(fig, 'instructions.png', options)
    

def _prepare_data(fig, ax, cpus, instructionEntries, columnName):
    data = pd.DataFrame(instructionEntries, columns=['realTime', 'virtualTime', 'cpuId', 'executedInstruction'])
    instructionLines = []

    for cpuId, cpuName in cpus.items():
        entries = data[data['cpuId'] == bytes([cpuId])]
        if entries.empty:
            continue
        line, = ax.plot(entries[columnName], entries['executedInstruction'], label=cpuName)
        instructionLines.append(line)

    return instructionLines
