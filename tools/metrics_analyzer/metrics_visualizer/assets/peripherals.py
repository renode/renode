import matplotlib.pyplot as plt
import pandas as pd

from .legend_picker import *
from .helpers import *


def show_peripheral_access(metricsParser, options, twoPlotFigureSize, fontSize):
    peripherals, peripheralEntries = metricsParser.get_peripheral_entries()
    data = pd.DataFrame(peripheralEntries, columns=['realTime', 'virtualTime', 'operation', 'address'])
    fig, (writesAx, readsAx) = plt.subplots(2, 1, figsize=twoPlotFigureSize, constrained_layout=True)

    writeLines = []
    readLines = []
    time_column = 'realTime' if options.real_time else 'virtualTime'

    for key, value in peripherals.items():
        tempData = data[data.address >= value[0]]
        peripheralEntries = tempData[tempData.address <= value[1]]
        readOperationFilter = peripheralEntries['operation'] == bytes([0])
        writeOperationFilter = peripheralEntries['operation'] == bytes([1])
        readEntries = peripheralEntries[readOperationFilter]
        writeEntries = peripheralEntries[writeOperationFilter]
        if not writeEntries.empty:
            writeLine, = writesAx.plot(writeEntries[time_column], range(0, len(writeEntries)), label=key)
            writeLines.append(writeLine)
        if not readEntries.empty:
            readLine, = readsAx.plot(readEntries[time_column], range(0, len(readEntries)), label=key)
            readLines.append(readLine)

    fig.suptitle('Peripheral access', fontsize=fontSize)
    writeHandles, writeLabels = writesAx.get_legend_handles_labels()
    readHandles, readLabels = readsAx.get_legend_handles_labels()
    writeLegend = fig.legend(writeHandles, writeLabels, loc='upper left')
    readLegend = fig.legend(readHandles, readLabels, loc='center left')
    set_legend_picker(fig, writeLines, writeLegend)
    set_legend_picker(fig, readLines, readLegend)

    x_label = '{} time [ms]'.format('Real' if options.real_time else 'Virtual')
    writesAx.set_xlabel(x_label)
    readsAx.set_xlabel(x_label)
    writesAx.set_ylabel('Write operations')
    readsAx.set_ylabel('Read operations')

    save_fig(fig, 'peripherals.png', options)
