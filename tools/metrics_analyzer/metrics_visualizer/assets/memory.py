import matplotlib.pyplot as plt
import pandas as pd

from .legend_picker import *
from .helpers import *

def show_memory_access(metricsParser, options, onePlotFigureSize, fontSize):
    memoryEntries = metricsParser.get_memory_entries()
    data = pd.DataFrame(memoryEntries, columns=['realTime', 'virtualTime', 'operation'])

    reads = data[data['operation'] == bytes([2])]
    writes = data[data['operation'] == bytes([3])]

    fig, ax = plt.subplots(figsize=onePlotFigureSize, constrained_layout=True)
    lines = _prepare_data(ax, reads, writes, 'realTime' if options.real_time else 'virtualTime')
    
    fig.suptitle('Memory access', fontsize=fontSize)
    handles, labels = ax.get_legend_handles_labels()
    legend = fig.legend(handles, labels, loc='upper left')
    set_legend_picker(fig, lines, legend)
    ax.set_xlabel('{} time [ms]'.format('Real' if options.real_time else 'Virtual'))
    
    save_fig(fig, 'memory.png', options)


def _prepare_data(ax, reads, writes, columnName):
    writeLines, = ax.plot(writes[columnName], range(0, len(writes)), label='Writes')
    readLines, = ax.plot(reads[columnName], range(0, len(reads)), label='Reads')
    ax.set_ylabel('Memory access operations')
    return [writeLines, readLines]
