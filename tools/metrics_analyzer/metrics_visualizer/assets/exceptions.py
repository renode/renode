import matplotlib.pyplot as plt
import pandas as pd

from .legend_picker import *
from .helpers import *


def show_exceptions(metricsParser, options, onePlotFigureSize, fontSize):
    exceptionEntries = metricsParser.get_exceptions_entries()
    data = pd.DataFrame(exceptionEntries, columns=['realTime', 'virtualTime', 'number'])
    fig, ax = plt.subplots(figsize=onePlotFigureSize, constrained_layout=True)
    time_column = 'realTime' if options.real_time else 'virtualTime'
    lines = _prepare_data(ax, data, time_column)

    fig.suptitle('Exceptions', fontsize=fontSize)
    ax.set_ylabel('Exception operations')
    ax.set_xlabel('{} time [ms]'.format('Real' if options.real_time else 'Virtual'))

    handles, labels = ax.get_legend_handles_labels()
    legend = fig.legend(handles, labels, loc='upper left')
    set_legend_picker(fig, lines, legend)
    save_fig(fig, 'exceptions.png', options)


def _prepare_data(ax, data, time_column):
    lines = []
    for index in data['number'].drop_duplicates():
        entries = data[data['number'] == index]
        line, = ax.plot(entries[time_column], range(0, len(entries)), label=index)
        lines.append(line)
    return lines
