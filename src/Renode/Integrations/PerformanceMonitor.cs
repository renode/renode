// PerformanceMonitor.cs
//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Collections.Generic;
using System.Threading;

namespace Antmicro.Renode.Integrations
{
    public enum CounterWidth
    {
        Bits32,
        Bits64
    }

    public enum PerformanceEventType
    {
        InstructionExecuted,
        MemoryRead,
        MemoryWrite,
        InterruptTaken,
        InterruptReturn,
        CacheMiss,
        CacheHit,
        BranchTaken,
        BranchMispredicted
    }

    public class PerformanceCounterOverflowEventArgs : EventArgs
    {
        public PerformanceCounterOverflowEventArgs(int counterIndex, ulong valueAtOverflow)
        {
            CounterIndex = counterIndex;
            ValueAtOverflow = valueAtOverflow;
        }

        public int CounterIndex { get; }
        public ulong ValueAtOverflow { get; }
    }

    public class PerformanceCounter
    {
        public PerformanceCounter(int index, CounterWidth width = CounterWidth.Bits64)
        {
            Index = index;
            Width = width;
            EventType = PerformanceEventType.InstructionExecuted;
            Enabled = false;
            Value = 0;
            OverflowCount = 0;
            maxValue = (width == CounterWidth.Bits32) ? uint.MaxValue : ulong.MaxValue;
        }

        public int Index { get; }
        public CounterWidth Width { get; set; }
        public PerformanceEventType EventType { get; set; }
        public bool Enabled { get; set; }
        public ulong Value { get; private set; }
        public ulong OverflowCount { get; private set; }
        public bool OverflowInterruptEnabled { get; set; }

        public event EventHandler<PerformanceCounterOverflowEventArgs> OnOverflow;

        public void Increment(ulong amount = 1)
        {
            if(!Enabled)
            {
                return;
            }

            var newValue = Value + amount;
            if(newValue > maxValue || newValue < Value)
            {
                OverflowCount++;
                newValue = newValue & maxValue;
                OnOverflow?.Invoke(this, new PerformanceCounterOverflowEventArgs(Index, Value));
            }
            Value = newValue;
        }

        public void Reset()
        {
            Value = 0;
            OverflowCount = 0;
        }

        public void SetValue(ulong value)
        {
            Value = value & maxValue;
        }

        private readonly ulong maxValue;
    }

    public class PerformanceMonitor
    {
        public const int MaxCounters = 32;

        // CSR-like register offsets
        public const uint RegisterControl       = 0x00;
        public const uint RegisterStatus        = 0x04;
        public const uint RegisterCounterBase   = 0x10;
        public const uint RegisterEventBase     = 0x80;
        public const uint RegisterOverflowFlags = 0xF0;
        public const uint RegisterCycleCountLow = 0xF4;
        public const uint RegisterCycleCountHigh = 0xF8;

        public PerformanceMonitor(int numberOfCounters = 6, CounterWidth defaultWidth = CounterWidth.Bits64)
        {
            if(numberOfCounters < 1 || numberOfCounters > MaxCounters)
            {
                throw new ArgumentOutOfRangeException(nameof(numberOfCounters),
                    $"Number of counters must be between 1 and {MaxCounters}");
            }

            this.numberOfCounters = numberOfCounters;
            counters = new PerformanceCounter[numberOfCounters];
            for(int i = 0; i < numberOfCounters; i++)
            {
                counters[i] = new PerformanceCounter(i, defaultWidth);
            }

            globalEnabled = false;
            cycleCount = 0;
            overflowFlags = 0;
            interruptLatencyStart = 0;
            lastInterruptLatency = 0;
            monitorLock = new object();

            for(int i = 0; i < numberOfCounters; i++)
            {
                var counterIndex = i;
                counters[i].OnOverflow += (sender, args) =>
                {
                    lock(monitorLock)
                    {
                        overflowFlags |= (1u << counterIndex);
                    }
                    CounterOverflow?.Invoke(this, args);
                };
            }
        }

        public event EventHandler<PerformanceCounterOverflowEventArgs> CounterOverflow;

        public void Enable()
        {
            lock(monitorLock)
            {
                globalEnabled = true;
            }
        }

        public void Disable()
        {
            lock(monitorLock)
            {
                globalEnabled = false;
            }
        }

        public bool IsEnabled
        {
            get
            {
                lock(monitorLock)
                {
                    return globalEnabled;
                }
            }
        }

        public void Reset()
        {
            lock(monitorLock)
            {
                for(int i = 0; i < numberOfCounters; i++)
                {
                    counters[i].Reset();
                    counters[i].Enabled = false;
                }
                cycleCount = 0;
                overflowFlags = 0;
                interruptLatencyStart = 0;
                lastInterruptLatency = 0;
            }
        }

        public void ConfigureCounter(int index, PerformanceEventType eventType,
                                      bool enabled = true, CounterWidth? width = null)
        {
            ValidateCounterIndex(index);
            lock(monitorLock)
            {
                counters[index].EventType = eventType;
                counters[index].Enabled = enabled;
                if(width.HasValue)
                {
                    counters[index].Width = width.Value;
                }
            }
        }

        public void RecordEvent(PerformanceEventType eventType, ulong count = 1)
        {
            if(!globalEnabled)
            {
                return;
            }

            lock(monitorLock)
            {
                for(int i = 0; i < numberOfCounters; i++)
                {
                    if(counters[i].Enabled && counters[i].EventType == eventType)
                    {
                        counters[i].Increment(count);
                    }
                }
            }
        }

        public void RecordInstructionExecuted(ulong count = 1)
        {
            RecordEvent(PerformanceEventType.InstructionExecuted, count);
            lock(monitorLock)
            {
                cycleCount += count;
            }
        }

        public void RecordMemoryRead(ulong count = 1)
        {
            RecordEvent(PerformanceEventType.MemoryRead, count);
        }

        public void RecordMemoryWrite(ulong count = 1)
        {
            RecordEvent(PerformanceEventType.MemoryWrite, count);
        }

        public void RecordInterruptEntry()
        {
            lock(monitorLock)
            {
                interruptLatencyStart = cycleCount;
            }
            RecordEvent(PerformanceEventType.InterruptTaken);
        }

        public void RecordInterruptExit()
        {
            lock(monitorLock)
            {
                if(interruptLatencyStart > 0)
                {
                    lastInterruptLatency = cycleCount - interruptLatencyStart;
                    interruptLatencyStart = 0;
                }
            }
            RecordEvent(PerformanceEventType.InterruptReturn);
        }

        public ulong GetInterruptLatency()
        {
            lock(monitorLock)
            {
                return lastInterruptLatency;
            }
        }

        public ulong GetCounterValue(int index)
        {
            ValidateCounterIndex(index);
            lock(monitorLock)
            {
                return counters[index].Value;
            }
        }

        public ulong GetCycleCount()
        {
            lock(monitorLock)
            {
                return cycleCount;
            }
        }

        public uint ReadRegister(uint offset)
        {
            lock(monitorLock)
            {
                if(offset == RegisterControl)
                {
                    return globalEnabled ? 1u : 0u;
                }
                else if(offset == RegisterStatus)
                {
                    return (uint)numberOfCounters;
                }
                else if(offset == RegisterOverflowFlags)
                {
                    return overflowFlags;
                }
                else if(offset == RegisterCycleCountLow)
                {
                    return (uint)(cycleCount & 0xFFFFFFFF);
                }
                else if(offset == RegisterCycleCountHigh)
                {
                    return (uint)(cycleCount >> 32);
                }
                else if(offset >= RegisterCounterBase
                        && offset < RegisterCounterBase + (uint)(numberOfCounters * 4))
                {
                    var idx = (int)(offset - RegisterCounterBase) / 4;
                    return (uint)(counters[idx].Value & 0xFFFFFFFF);
                }
                else if(offset >= RegisterEventBase
                        && offset < RegisterEventBase + (uint)(numberOfCounters * 4))
                {
                    var idx = (int)(offset - RegisterEventBase) / 4;
                    return (uint)counters[idx].EventType;
                }

                return 0;
            }
        }

        public void WriteRegister(uint offset, uint value)
        {
            lock(monitorLock)
            {
                if(offset == RegisterControl)
                {
                    globalEnabled = (value & 1) != 0;
                }
                else if(offset == RegisterOverflowFlags)
                {
                    // Write-1-to-clear semantics
                    overflowFlags &= ~value;
                }
                else if(offset >= RegisterCounterBase
                        && offset < RegisterCounterBase + (uint)(numberOfCounters * 4))
                {
                    var idx = (int)(offset - RegisterCounterBase) / 4;
                    counters[idx].SetValue(value);
                }
                else if(offset >= RegisterEventBase
                        && offset < RegisterEventBase + (uint)(numberOfCounters * 4))
                {
                    var idx = (int)(offset - RegisterEventBase) / 4;
                    if(Enum.IsDefined(typeof(PerformanceEventType), (int)value))
                    {
                        counters[idx].EventType = (PerformanceEventType)value;
                    }
                }
            }
        }

        public PerformanceCounter GetCounter(int index)
        {
            ValidateCounterIndex(index);
            return counters[index];
        }

        public int NumberOfCounters => numberOfCounters;

        private void ValidateCounterIndex(int index)
        {
            if(index < 0 || index >= numberOfCounters)
            {
                throw new ArgumentOutOfRangeException(nameof(index),
                    $"Counter index must be between 0 and {numberOfCounters - 1}");
            }
        }

        private readonly PerformanceCounter[] counters;
        private readonly int numberOfCounters;
        private readonly object monitorLock;
        private bool globalEnabled;
        private ulong cycleCount;
        private uint overflowFlags;
        private ulong interruptLatencyStart;
        private ulong lastInterruptLatency;
    }
}
