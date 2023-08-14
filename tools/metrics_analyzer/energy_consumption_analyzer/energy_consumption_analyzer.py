#!/usr/bin/python3

import sys
import os
import struct
import typer
from typing_extensions import Annotated
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from metrics_parser import MetricsParser

# Data deserialization
def getWfisData(mp):
    wfi_starts = mp.get_wfi_start_entries()
    wfi_ends = mp.get_wfi_end_entries()

    # Aggregation of wfi events
    wfis = [(round(wfi_starts[i][1], 3), round(wfi_ends[i][1], 3), round((wfi_ends[i][1] - wfi_starts[i][1]), 3)) for i in range(len(wfi_ends))]
    data = pd.DataFrame(wfis, columns=['wfiStartTimestamp', 'wfiEndTimestamp', 'timeInWfi'])
    return data

def getBitsData(mp):
    bitsNames, bits = mp.get_bits_entries()
    # Replace bit nameIDs with strings from bitsNames
    for bit in bits:
        bit[2] = bitsNames[bit[2]]
    data = pd.DataFrame(bits, columns=['realTime', 'virtualTime', 'entryName', 'enabled'])
    bitsDict = {}
    for name in bitsNames.values():
        if ':' not in name:
            raise ValueError(f'Bit with name: {name} can\'t be analyzed. Names must be in format: <peripheral name>:[CLOCK|ENABLE].')
        peripheralName, bitType = name.split(':')
        if bitType != 'CLOCK' and bitType != 'ENABLE':
            raise ValueError(f'Bit with name: {name} can\'t be analyzed. Names must be in format: <peripheral name>:[CLOCK|ENABLE].')
        if peripheralName not in bitsDict:
            bitsDict[peripheralName] = {}
        bitsDict[peripheralName][bitType] = data[data['entryName'] == name]
    return bitsDict

def getEndOfSimulationTime(mp):
    return mp.get_EOS_entries()[0][1]

# Data presentation
def printWfis(data):
    print('--------------------------------------')
    print('Printing wfi entries')
    print('--------------------------------------')
    print(data)
    print('--------------------------------------')
    print('Done')
    print('--------------------------------------')

def printBits(bitsDict):
    print('--------------------------------------')
    print('Printing bits entries')
    print('--------------------------------------')
    for peripheral in bitsDict:
        for bitType in bitsDict[peripheral]:
            bitName = f'{peripheral}:{bitType}'
            print(f'BitName: {bitName}')
            print(bitsDict[peripheral][bitType])
            print('--------------------------------------')
    print('Done')
    print('--------------------------------------')

def wfiTimePercentage(wfisData, simTime):
    print('--------------------------------------')
    print('Printing wfi statistics')
    print('--------------------------------------')
    sumOfWfiDelta = wfisData['timeInWfi'].sum()
    wfiPercent = round(sumOfWfiDelta / simTime * 100, 3)
    print(f'Total time spent in WFI: {sumOfWfiDelta}ms')
    print(f'Total simulation time: {simTime}ms')
    print(f'How much percent of simulation time was spent in wfi: {wfiPercent}%')
    print('--------------------------------------')
    print('Done')
    print('--------------------------------------')

def bitsTimePercentage(bitsDict, simTime):
    print('--------------------------------------')
    print('Printing bits statistics')
    print('--------------------------------------')
    for peripheral in bitsDict:
        for bitType in bitsDict[peripheral]:
            bitData = bitsDict[peripheral][bitType]
            startTime = 0.0
            sumOfPeriods = 0.0
            enabled = False
            for _, entry in bitData.iterrows():
                if entry['enabled'] == 1:
                    startTime = entry['virtualTime']
                    enabled = True
                elif entry['enabled'] == 0:
                    sumOfPeriods += entry['virtualTime'] - startTime
                    startTime = 0.0
                    enabled = False
            #If the last entry enabled the bit then we count the last period till the end of simulation
            if enabled:
                sumOfPeriods += simTime - startTime
            bitEnabledTimePercent = round(sumOfPeriods / simTime * 100, 3)
            bitName = f'{peripheral}:{bitType}'
            print(f'Statistics for {bitName}')
            print(f'Total time the bit was enabled: {sumOfPeriods}ms')
            print(f'Total simulation time: {simTime}ms')
            print(f'How much percent of simulation time {bitName} was enabled: {bitEnabledTimePercent}%')
            print('--------------------------------------')
    print('Done')
    print('--------------------------------------')

def plotWfis(wfiData, simTime):
    fig = plt.figure("WFI graph")
    fig.set_figheight(2)
    fig.tight_layout(pad=3.0)
    xs = []
    ys = []
    for _, wfiEntry in wfiData.iterrows():
        xs.append(wfiEntry['wfiStartTimestamp'])
        xs.append(wfiEntry['wfiEndTimestamp'])
        ys.append(1)
        ys.append(0)
    #Assumption that at the very beginning CPU isn't in WFI state and at the end of simulation it stays in the state it was.
    xs = [0.0] + xs + [simTime]
    ys = [0] + ys
    ys.append(ys[-1])
    plt.title('CPU in WFI state')
    plt.xlabel('Time in milliseconds')
    plt.yticks([0,1])
    plt.plot(xs,ys, label='Is Cpu in WFI?', drawstyle='steps-post')
    plt.legend()
    plt.grid()

def plotSingleBit(ax, name, peripheral, simTime):
    ax.set_title(name)
    ax.set_xlabel('Time in milliseconds')
    ax.set_yticks([0,1])
    xs1 = []
    xs2 = []
    ys1 = []
    ys2 = []
    clockBit = peripheral['CLOCK']
    enableBit = peripheral['ENABLE']
    for _, entry in clockBit.iterrows():
        xs1.append(entry['virtualTime'])
        ys1.append(entry['enabled'])
    for _, entry in enableBit.iterrows():
        xs2.append(entry['virtualTime'])
        ys2.append(entry['enabled'])
    #Assumption that the last state of bits doesn't change until the end of simulation
    xs2 = xs2 + [simTime]
    xs1 = xs1 + [simTime]
    ys1.append(ys1[-1])
    ys2.append(ys2[-1])
    print(xs1)
    print(ys1)
    ax.plot(xs1, ys1, label='clock', linewidth=2, drawstyle='steps-post')
    ax.plot(xs2, ys2, label='enable', linestyle='dashed', linewidth=2, drawstyle='steps-post', alpha=0.7)
    ax.legend()
    ax.grid()

def plotBits(bitsDict, simTime):
    fig, axs = plt.subplots(len(bitsDict), 1)
    fig.set_figheight(2)
    fig.tight_layout(pad=3.0)
    fig.canvas.manager.set_window_title('Bits Graphs')
    if not isinstance(axs, np.ndarray):
        axs = [axs]
    i = 0
    for peripheral in bitsDict:
        plotSingleBit(axs[i], peripheral, bitsDict[peripheral], simTime)
        i += 1


def main(filename: Annotated[str, typer.Argument()],
         wfisList: Annotated[bool, typer.Option("--wfis-list/ ")] = False,
         wfisStatistics: Annotated[bool, typer.Option("--wfis-statistics/ ")] = False,
         wfisGraphs: Annotated[bool, typer.Option("--wfis-graphs/ ")] = False,
         bitsList: Annotated[bool, typer.Option("--bits-list/ ")] = False,
         bitsStatistics: Annotated[bool, typer.Option("--bits-statistics/ ")] = False,
         bitsGraphs: Annotated[bool, typer.Option("--bits-graphs/ ")] = False):

    #Default behaviour when no options are passes is to show everything
    if not wfisList and not wfisStatistics and not wfisGraphs and not bitsList and not bitsStatistics and not bitsGraphs:
        wfisList = True
        wfisStatistics = True
        wfisGraphs = True
        bitsList = True
        bitsStatistics = True
        bitsGraphs = True

    if not os.path.exists(filename):
        raise ValueError(f"File {filename} doesn't exist")

    mp = MetricsParser(filename)
    if wfisList or wfisStatistics or wfisGraphs:
        wfisData = getWfisData(mp)
    if bitsList or bitsStatistics or bitsGraphs:
        bitsData = getBitsData(mp)
    if bitsStatistics or bitsGraphs or wfisStatistics or wfisGraphs:
        simTime = getEndOfSimulationTime(mp)

    if wfisList:
        printWfis(wfisData)
    if wfisStatistics:
        wfiTimePercentage(wfisData, simTime)
    if wfisGraphs:
        plotWfis(wfisData, simTime)
    if bitsList:
        printBits(bitsData)
    if bitsStatistics:
        bitsTimePercentage(bitsData, simTime)
    if bitsGraphs:
        plotBits(bitsData, simTime)

    if bitsGraphs or wfisGraphs:
        plt.show()

if __name__ == "__main__":
    typer.run(main)
