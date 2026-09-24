//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.Debugging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Utilities;

using ELFSharp.ELF.Sections;

#nullable enable

namespace Antmicro.Renode.RobotFramework
{
    internal partial class MemoryKeywords : IRobotFrameworkKeywordProvider
    {
        public void Dispose()
        {
        }

        [RobotFrameworkKeyword]
        public void StoreAssembledCode(ulong address, string assembly, string? triple = null, bool alternateDialect = false, string? machine = null, int? cpu = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            var cpus = sysbus.GetCPUs();
            if(cpus.Count() == 0)
            {
                throw new KeywordException($"{machine ?? "This machine"} has no CPUs.");
            }
            if(cpus.Count() > 1 && cpu == null)
            {
                throw new KeywordException($"There is >1 CPU in {machine ?? "this machine"} but a name of the CPU to assemble for was not specified. Available CPUs: {Misc.PrettyPrintCollection(cpus)}");
            }
            var icpu = cpus.ElementAt(cpu ?? 0);
            if(icpu is TranslationCPU tcpu)
            {
                char[] toTrim = { '\"', '\'' };
                assembly = assembly.Trim(toTrim);
                tcpu.AssembleBlock(address, assembly, triple, alternateDialect);
            }
            else
            {
                throw new KeywordException($"{icpu.GetCPUThreadName(machineObj)} does not support assembling code");
            }
        }

        [RobotFrameworkKeyword]
        public void AddSymbol(string name, ulong start, ulong size = (ulong)SysbusAccessWidth.DoubleWord, SymbolType type = SymbolType.NotSpecified,
                              SymbolBinding binding = SymbolBinding.Global, bool isThumb = false, string? machine = null, string? context = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            GetLookup(machineObj, sysbus, context).InsertSymbol(name, start, size, type, binding, isThumb);
        }

        private static string? GetComparisonDescription(ComparisonType compType)
        {
            switch(compType)
            {
            case ComparisonType.Equal: return "equal to";
            case ComparisonType.NotEqual: return "unequal to";
            case ComparisonType.LessThan: return "less than";
            case ComparisonType.LessOrEqual: return "less or equal";
            case ComparisonType.GreaterThan: return "greater than";
            case ComparisonType.GreaterOrEqual: return "greater or equal";
            default: return null;
            }
        }

        private static bool Compare<T>(T actual, T value, ComparisonType compType) where T : INumber<T>
        {
            switch(compType)
            {
            case ComparisonType.Equal:
                return actual == value;
            case ComparisonType.NotEqual:
                return actual != value;
            case ComparisonType.LessThan:
                return actual < value;
            case ComparisonType.LessOrEqual:
                return actual <= value;
            case ComparisonType.GreaterThan:
                return actual > value;
            case ComparisonType.GreaterOrEqual:
                return actual >= value;
            default:
                throw new ArgumentException("Invalid comparison type");
            }
        }

        private static ulong GetEffectiveAddress(ulong address, SysbusAccessWidth accessWidth, long offset)
        {
            if(offset < 0)
            {
                return address - (ulong)accessWidth * (ulong)-offset;
            }
            else
            {
                return address + (ulong)accessWidth * (ulong)offset;
            }
        }

        private static bool CompareOuter(ulong actual, ulong value, ComparisonType type, SysbusAccessWidth accessWidth, bool signed)
        {
            switch(accessWidth)
            {
            case SysbusAccessWidth.Byte:
                return signed ? Compare((sbyte)actual, (sbyte)value, type) : Compare((byte)actual, (byte)value, type);
            case SysbusAccessWidth.Word:
                return signed ? Compare((short)actual, (short)value, type) : Compare((ushort)actual, (ushort)value, type);
            case SysbusAccessWidth.DoubleWord:
                return signed ? Compare((int)actual, (int)value, type) : Compare((uint)actual, (uint)value, type);
            case SysbusAccessWidth.QuadWord:
                return signed ? Compare((long)actual, (long)value, type) : Compare(actual, value, type);
            default:
                return false;
            }
        }

        private static string GetOffsetString(long offset, SysbusAccessWidth accessWidth)
        {
            if(offset == 0)
            {
                return "";
            }
            return offset > 0 ? "+" : "-" + $"0x{(ulong)Math.Abs(offset) * (ulong)accessWidth:x}";
        }

        private static void ReportSingleThingError(ulong? actual, ulong value, string thing, SysbusAccessWidth accessWidth, long offset, ComparisonType compType, float? timeout, bool isSymbol)
        {
            var compDesc = GetComparisonDescription(compType);
            var tense = timeout.HasValue ? "did not become" : "is not";
            var timeoutSuffix = timeout.HasValue ? $" after {timeout.Value} seconds" : "";
            var actualValue = actual.HasValue ? $": got 0x{actual.Value:x}" : "";
            var at = isSymbol ? "of" : "at address";
            var offsetValue = GetOffsetString(offset, accessWidth);
            throw new KeywordException($"Value {at} {thing}{offsetValue} {tense} {compDesc} 0x{value:x}{timeoutSuffix}{actualValue}");
        }

        private static void ReportMemoryError(ulong? actual, ulong value, ulong address, SysbusAccessWidth accessWidth, ComparisonType compType, float? timeout = null)
        {
            ReportSingleThingError(actual, value, $"0x{address:x}", accessWidth, 0, compType, timeout, false);
        }

        private static void ReportSymbolError(ulong? actual, ulong value, string name, SysbusAccessWidth accessWidth, long offset, ComparisonType compType, float? timeout = null)
        {
            ReportSingleThingError(actual, value, name, accessWidth, offset, compType, timeout, true);
        }

        private static void ReportManySymbolsError(ulong value, string name, SysbusAccessWidth accessWidth, long offset, ComparisonType compType, float? timeout, bool all)
        {
            var compDesc = GetComparisonDescription(compType);
            var timeoutSuffix = timeout.HasValue ? $" after {timeout.Value} seconds" : "";
            var prefix = all ? "Not all" : "No";
            var stmt = all ? "symbols have" : "symbol has";
            var offsetValue = GetOffsetString(offset, accessWidth);
            throw new KeywordException($"{prefix} {name}{offsetValue} {stmt} a value {compDesc} 0x{value:x}{timeoutSuffix}");
        }

        private static void ReportAllSymbolsError(ulong value, string name, SysbusAccessWidth accessWidth, long offset, ComparisonType compType, float? timeout = null)
        {
            ReportManySymbolsError(value, name, accessWidth, offset, compType, timeout, true);
        }

        private static void ReportAnySymbolError(ulong value, string name, SysbusAccessWidth accessWidth, long offset, ComparisonType compType, float? timeout = null)
        {
            ReportManySymbolsError(value, name, accessWidth, offset, compType, timeout, false);
        }

        private static BusHookDelegate MakeBusHook(ulong value, ComparisonType compType, SysbusAccessWidth accessWidth, bool signed, Action onSame, Action? onNotSame = null)
        {
            BusHookDelegate hook = (_, _, writeAccessWidth, valueWritten) =>
            {
                DebugHelper.Assert(writeAccessWidth == accessWidth);
                if(CompareOuter(valueWritten, value, compType, writeAccessWidth, signed))
                {
                    onSame();
                }
                else if(onNotSame != null)
                {
                    onNotSame();
                }
            };
            return hook;
        }

        private static ICPU GetCPUByName(IMachine machine, IEnumerable<ICPU> cpus, string name)
        {
            var cpu = cpus.FirstOrDefault(cpu => machine.GetLocalName(cpu) == name);
            return cpu ?? throw new KeywordException($"CPU {name} not found");
        }

        private static SymbolLookup GetLookup(IMachine machine, IBusController sysbus, string? context)
        {
            return sysbus.GetLookup(context == null ? null : GetCPUByName(machine, sysbus.GetCPUs(), context));
        }

        private static (Action, Action) MakeAllSymbolsComparisonCallbacks(CountdownEvent cde, object cdeLock)
        {
            var onSame = () =>
            {
                lock(cdeLock)
                {
                    if(!cde.IsSet)
                    {
                        cde.Signal();
                    }
                }
            };
            var onNotSame = () =>
            {
                lock(cdeLock)
                {
                    if(cde.CurrentCount < cde.InitialCount)
                    {
                        cde.TryAddCount();
                    }
                }
            };
            return (onSame, onNotSame);
        }

        private void MemoryShouldBe(ulong address, ulong value, SysbusAccessWidth accessWidth, bool signed, float? timeout, string? machine, bool pauseEmulation, ComparisonType compType)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;

            if(timeout.HasValue)
            {
                MemoryShouldBeAfter(address, value, accessWidth, signed, timeout.Value, pauseEmulation, sysbus, compType);
                return;
            }
            var actual = ReadAddress(sysbus, address, accessWidth);
            var same = CompareOuter(actual, value, compType, accessWidth, signed);
            if(!same)
            {
                ReportMemoryError(actual, value, address, accessWidth, compType);
            }
        }

        private void SymbolsShouldBe(string name, ulong value, SysbusAccessWidth accessWidth, bool signed, long offset, float? timeout, string? machine, string? context, bool pauseEmulation, ComparisonType compType, SymbolLookupMode lookupMode)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            var lookup = GetLookup(machineObj, sysbus, context);
            var symbols = lookup.GetSymbolsByName(name);
            CheckSymbolsOrReportError(symbols, name, lookupMode);

            if(timeout.HasValue)
            {
                SymbolsShouldBeAfter(name, value, accessWidth, signed, offset, timeout.Value, pauseEmulation, symbols, sysbus, compType, lookupMode);
                return;
            }
            switch(lookupMode)
            {
            case SymbolLookupMode.Single:
            {
                var address = symbols.First().Start.RawValue;
                address = GetEffectiveAddress(address, accessWidth, offset);
                var actual = ReadAddress(sysbus, address, accessWidth);
                var same = CompareOuter(actual, value, compType, accessWidth, signed);
                if(!same)
                {
                    ReportSymbolError(actual, value, name, accessWidth, offset, compType, null);
                }
                break;
            }
            case SymbolLookupMode.All:
            case SymbolLookupMode.AllIndependently:
            {
                var same = true;
                foreach(var symbol in symbols)
                {
                    var address = symbol.Start.RawValue;
                    address = GetEffectiveAddress(address, accessWidth, offset);
                    same = same && CompareOuter(ReadAddress(sysbus, address, accessWidth), value, compType, accessWidth, signed);
                }
                if(!same)
                {
                    ReportAllSymbolsError(value, name, accessWidth, offset, compType);
                }
                break;
            }
            case SymbolLookupMode.Any:
            {
                var same = false;
                foreach(var symbol in symbols)
                {
                    var address = symbol.Start.RawValue;
                    address = GetEffectiveAddress(address, accessWidth, offset);
                    same = same || CompareOuter(ReadAddress(sysbus, address, accessWidth), value, compType, accessWidth, signed);
                }
                if(!same)
                {
                    ReportAnySymbolError(value, name, accessWidth, offset, compType);
                }
                break;
            }
            }
        }

        private void MemoryShouldBeAfter(ulong address, ulong value, SysbusAccessWidth accessWidth, bool signed, float timeout, bool pauseEmulation, IBusController sysbus, ComparisonType compType)
        {
            var callbacks = new TimeoutAssertionCallbacks
            (
                create: (waitHandles, hooks) =>
                {
                    var mre = new ManualResetEvent(false);
                    var hook = MakeBusHook(value, compType, accessWidth, signed, () => mre.Set());
                    waitHandles.Add(mre);
                    hooks.Add(hook);
                },
                setup: (hooks) => sysbus.AddWatchpointHook(address, accessWidth, Access.Write, hooks[0]),
                signaled: (emulation, waitHandles, hooks, which) =>
                {
                    if(which == 0)
                    {
                        var actual = ReadAddress(sysbus, address, accessWidth);
                        ReportMemoryError(actual, value, address, accessWidth, compType, timeout);
                    }
                    return false;
                },
                cleanup: (hooks) => sysbus.RemoveWatchpointHook(address, hooks[0])
            );
            ShouldBeAfter(timeout, pauseEmulation, callbacks);
        }

        private void SymbolsShouldBeAfter(string name, ulong value, SysbusAccessWidth accessWidth, bool signed, long offset, float timeout, bool pauseEmulation, IReadOnlyCollection<Symbol> symbols, IBusController sysbus, ComparisonType compType, SymbolLookupMode lookupMode)
        {
            var ready = 0;
            var callbacks = new TimeoutAssertionCallbacks
            (
                create: (waitHandles, hooks) =>
                {
                    if(lookupMode == SymbolLookupMode.All)
                    {
                        var cde = new CountdownEvent(symbols.Count);
                        var cdeLock = new object {};
                        var (onSame, onNotSame) = MakeAllSymbolsComparisonCallbacks(cde, cdeLock);
                        var hook = MakeBusHook(value, compType, accessWidth, signed, onSame, onNotSame);
                        waitHandles.Add(cde.WaitHandle);
                        foreach(var symbol in symbols)
                        {
                            hooks.Add(hook);
                        }
                    }
                    else
                    {
                        foreach(var symbol in symbols)
                        {
                            var mre = new ManualResetEvent(false);
                            var hook = MakeBusHook(value, compType, accessWidth, signed, () => mre.Set());
                            waitHandles.Add(mre);
                            hooks.Add(hook);
                        }
                    }
                },
                setup: (hooks) =>
                {
                    var i = 0;
                    foreach(var symbol in symbols)
                    {
                        var address = GetEffectiveAddress(symbol.Start.RawValue, accessWidth, offset);
                        sysbus.AddWatchpointHook(address, accessWidth, Access.Write, hooks[i++]);
                    }
                },
                signaled: (emulation, waitHandles, hooks, which) =>
                {
                    if(which == 0)
                    {
                        switch(lookupMode)
                        {
                        case SymbolLookupMode.Single:
                            ReportSymbolError(null, value, name, accessWidth, offset, compType, timeout);
                            break;
                        case SymbolLookupMode.All:
                            ReportAllSymbolsError(value, name, accessWidth, offset, compType, timeout);
                            break;
                        case SymbolLookupMode.AllIndependently:
                            ReportAllSymbolsError(value, name, accessWidth, offset, compType, timeout);
                            break;
                        case SymbolLookupMode.Any:
                            ReportAnySymbolError(value, name, accessWidth, offset, compType, timeout);
                            break;
                        }
                    }
                    if(lookupMode == SymbolLookupMode.AllIndependently)
                    {
                        var symbol = symbols.ElementAt(which - 1);
                        var address = GetEffectiveAddress(symbol.Start.RawValue, accessWidth, offset);
                        emulation.PauseAll();
                        sysbus.RemoveWatchpointHook(address, hooks[which - 1]);
                        emulation.StartAll();
                        // The hook can't be removed from the list as it'd break the mapping of
                        // symbol index <=> hook index, which is needed for final cleanup.
                        hooks[which - 1] = null;
                        waitHandles.RemoveAt(which);
                        return ++ready != symbols.Count;
                    }
                    else
                    {
                        return false;
                    }
                },
                cleanup: (hooks) =>
                {
                    var i = 0;
                    foreach(var symbol in symbols)
                    {
                        if(hooks[i] != null)
                        {
                            var address = GetEffectiveAddress(symbol.Start.RawValue, accessWidth, offset);
                            sysbus.RemoveWatchpointHook(address, hooks[i]);
                        }
                        ++i;
                    }
                }
            );
            ShouldBeAfter(timeout, pauseEmulation, callbacks);
        }

        private void ShouldBeAfter(float timeout, bool pauseEmulation, TimeoutAssertionCallbacks callbacks)
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            var masterTimeSource = emulation.MasterTimeSource;
            var timeoutEvent = masterTimeSource.EnqueueTimeoutEvent((uint)(timeout * 1000));
            var waitHandles = new List<WaitHandle>(2);
            var hooks = new List<BusHookDelegate?>(1);
            waitHandles.Add(timeoutEvent.WaitHandle);

            callbacks.Create(waitHandles, hooks);

            emulation.PauseAll();
            callbacks.Setup(hooks);
            emulation.StartAll();

            try
            {
                var which = -1;
                do
                {
                    // Note that reset events are indexed from 1. Index 0 is for the timeout event.
                    which = WaitHandle.WaitAny(waitHandles.ToArray());
                } while(callbacks.Signaled(emulation, waitHandles, hooks, which));
                timeoutEvent.Cancel();
            }
            finally
            {
                emulation.PauseAll();
                callbacks.Cleanup(hooks);
                if(!pauseEmulation)
                {
                    emulation.StartAll();
                }
            }
        }

        private void CheckSymbolsOrReportError(IReadOnlyCollection<Symbol> symbols, string name, SymbolLookupMode lookupMode)
        {
            if(symbols.Count == 0)
            {
                throw new KeywordException($"Symbol {name} not found");
            }
            if(symbols.Count > 1 && lookupMode == SymbolLookupMode.Single)
            {
                throw new KeywordException($"Expected a single symbol {name}, but got {symbols.Count}");
            }
        }

        private IMachine GetMachineByNameOrSingle(string? machineName = null)
        {
            var emulation = EmulationManager.Instance.CurrentEmulation;
            IMachine machine;

            if(machineName == null)
            {
                if(emulation.MachinesCount == 0)
                {
                    throw new KeywordException("There are no machines in the emulation.");
                }

                if(emulation.MachinesCount > 1)
                {
                    throw new KeywordException("There is more than 1 machine and no machine name was specified. Available machines: {0}",
                        Misc.PrettyPrintCollection(emulation.Machines));
                }

                machine = emulation.Machines.Single();
            }
            else if(!emulation.TryGetMachineByName(machineName, out machine))
            {
                throw new KeywordException("Machine with name {0} not found. Available machines: {1}",
                    machineName, Misc.PrettyPrintCollection(emulation.Machines));
            }

            return machine;
        }

        private ulong ReadAddress(IBusController sysbus, ulong address, SysbusAccessWidth accessWidth)
        {
            switch(accessWidth)
            {
            case SysbusAccessWidth.Byte:
                return sysbus.ReadByte(address);
            case SysbusAccessWidth.Word:
                return sysbus.ReadWord(address);
            case SysbusAccessWidth.DoubleWord:
                return sysbus.ReadDoubleWord(address);
            case SysbusAccessWidth.QuadWord:
                return sysbus.ReadQuadWord(address);
            default:
                throw new ArgumentException("Invalid access width");
            }
        }

        private void WriteAddress(IBusController sysbus, ulong address, ulong value, SysbusAccessWidth accessWidth)
        {
            switch(accessWidth)
            {
            case SysbusAccessWidth.Byte:
                sysbus.WriteByte(address, (byte)value);
                break;
            case SysbusAccessWidth.Word:
                sysbus.WriteWord(address, (ushort)value);
                break;
            case SysbusAccessWidth.DoubleWord:
                sysbus.WriteDoubleWord(address, (uint)value);
                break;
            case SysbusAccessWidth.QuadWord:
                sysbus.WriteQuadWord(address, value);
                break;
            default:
                throw new ArgumentException("Invalid access width");
            }
        }

        private Symbol GetSymbol(string name, int? index, IMachine machine, IBusController sysbus, string? context)
        {
            var lookup = GetLookup(machine, sysbus, context);
            var symbols = lookup.GetSymbolsByName(name);
            if(symbols.Count == 0)
            {
                throw new KeywordException($"Symbol {name} not found");
            }

            if(symbols.Count > 1)
            {
                if(index is null)
                {
                    string symbolAddressPairs = string.Join(", ", symbols.Select((symbol, index) => $"{index}: 0x{symbol.Start.RawValue:x}"));
                    throw new KeywordException($"There are multiple symbols with the name {name}, but an index to choose which one was not given. Available symbols: [{symbolAddressPairs}]");
                }
                return symbols.ElementAt(index.Value);
            }
            else
            {
                return symbols.First();
            }
        }

        private void StoreValueAtSymbolAddress(string name, ulong value, SysbusAccessWidth accessWidth, long offset = 0, int? index = null, string? machine = null, string? context = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            var symbol = GetSymbol(name, index, machineObj, sysbus, context);
            var address = GetEffectiveAddress(symbol.Start.RawValue, accessWidth, offset);
            WriteAddress(sysbus, address, value, accessWidth);
        }

        private struct TimeoutAssertionCallbacks
        {
            public CreateHooksAndWaitables Create { get; set; }

            public SetupWatchpoints Setup { get; set; }

            public HandleSignaled Signaled { get; set; }

            public CleanupWatchpoints Cleanup { get; set; }

            public TimeoutAssertionCallbacks(CreateHooksAndWaitables create, SetupWatchpoints setup, HandleSignaled signaled, CleanupWatchpoints cleanup)
            {
                Create = create;
                Setup = setup;
                Signaled = signaled;
                Cleanup = cleanup;
            }
        }

        private delegate void CreateHooksAndWaitables(List<WaitHandle> waitHandles, List<BusHookDelegate?> hooks);

        private delegate void SetupWatchpoints(List<BusHookDelegate?> hooks);

        private delegate bool HandleSignaled(Emulation emulation, List<WaitHandle> waitHandles, List<BusHookDelegate?> hooks, int which);

        private delegate void CleanupWatchpoints(List<BusHookDelegate?> hooks);

        private enum ComparisonType
        {
            Equal           = 0,
            NotEqual        = 1,
            LessThan        = 2,
            LessOrEqual     = 3,
            GreaterThan     = 4,
            GreaterOrEqual  = 5,
        }

        private enum SymbolLookupMode
        {
            Single  = 0,
            All     = 1,
            Any     = 2,
            AllIndependently = 3,
        }
    }
}
