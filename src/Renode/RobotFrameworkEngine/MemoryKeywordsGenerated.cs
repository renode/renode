/********************************************************
*
* Warning!
* This file was generated automatically.
* Please do not edit. Changes should be made in the
* appropriate *.tt file.
*
*/

using Antmicro.Renode.Peripherals.Bus;

#nullable enable

namespace Antmicro.Renode.RobotFramework
{
    internal partial class MemoryKeywords
    {
        [RobotFrameworkKeyword]
        public void StoreByte(ulong address, byte value, string? machine = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            sysbus.WriteByte(address, value);
        }

        [RobotFrameworkKeyword]
        public void StoreByte(string symbol, byte value, long offset = 0, int? index = null, string? machine = null)
        {
            StoreValueAtSymbolAddress(symbol, value, SysbusAccessWidth.Byte, offset, index, machine);
        }

        [RobotFrameworkKeyword]
        public void StoreWord(ulong address, ushort value, string? machine = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            sysbus.WriteWord(address, value);
        }

        [RobotFrameworkKeyword]
        public void StoreWord(string symbol, ushort value, long offset = 0, int? index = null, string? machine = null)
        {
            StoreValueAtSymbolAddress(symbol, value, SysbusAccessWidth.Word, offset, index, machine);
        }

        [RobotFrameworkKeyword]
        public void StoreDoubleWord(ulong address, uint value, string? machine = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            sysbus.WriteDoubleWord(address, value);
        }

        [RobotFrameworkKeyword]
        public void StoreDoubleWord(string symbol, uint value, long offset = 0, int? index = null, string? machine = null)
        {
            StoreValueAtSymbolAddress(symbol, value, SysbusAccessWidth.DoubleWord, offset, index, machine);
        }

        [RobotFrameworkKeyword]
        public void StoreQuadWord(ulong address, ulong value, string? machine = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            sysbus.WriteQuadWord(address, value);
        }

        [RobotFrameworkKeyword]
        public void StoreQuadWord(string symbol, ulong value, long offset = 0, int? index = null, string? machine = null)
        {
            StoreValueAtSymbolAddress(symbol, value, SysbusAccessWidth.QuadWord, offset, index, machine);
        }

        [RobotFrameworkKeyword]
        public void StoreByte(ulong address, sbyte value, string? machine = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            sysbus.WriteByte(address, (byte)value);
        }

        [RobotFrameworkKeyword]
        public void StoreByte(string symbol, sbyte value, long offset = 0, int? index = null, string? machine = null, string? context = null)
        {
            StoreValueAtSymbolAddress(symbol, (byte)value, SysbusAccessWidth.Byte, offset, index, machine, context);
        }

        [RobotFrameworkKeyword]
        public void StoreWord(ulong address, short value, string? machine = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            sysbus.WriteWord(address, (ushort)value);
        }

        [RobotFrameworkKeyword]
        public void StoreWord(string symbol, short value, long offset = 0, int? index = null, string? machine = null, string? context = null)
        {
            StoreValueAtSymbolAddress(symbol, (ushort)value, SysbusAccessWidth.Word, offset, index, machine, context);
        }

        [RobotFrameworkKeyword]
        public void StoreDoubleWord(ulong address, int value, string? machine = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            sysbus.WriteDoubleWord(address, (uint)value);
        }

        [RobotFrameworkKeyword]
        public void StoreDoubleWord(string symbol, int value, long offset = 0, int? index = null, string? machine = null, string? context = null)
        {
            StoreValueAtSymbolAddress(symbol, (uint)value, SysbusAccessWidth.DoubleWord, offset, index, machine, context);
        }

        [RobotFrameworkKeyword]
        public void StoreQuadWord(ulong address, long value, string? machine = null)
        {
            var machineObj = GetMachineByNameOrSingle(machine);
            var sysbus = machineObj.SystemBus;
            sysbus.WriteQuadWord(address, (ulong)value);
        }

        [RobotFrameworkKeyword]
        public void StoreQuadWord(string symbol, long value, long offset = 0, int? index = null, string? machine = null, string? context = null)
        {
            StoreValueAtSymbolAddress(symbol, (ulong)value, SysbusAccessWidth.QuadWord, offset, index, machine, context);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeEqual(ulong address, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            MemoryShouldBe(address, value, width, signed, timeout, machine, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeEqual(ulong address, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(MemoryShouldBeEqual)} without setting `signed=true`");
            }
            MemoryShouldBe(address, (ulong)value, width, signed, timeout, machine, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldIndependentlyBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldIndependentlyBeEqual)} without setting `signed=true`");
            }
            AllSymbolsShouldIndependentlyBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldNotBeEqual(ulong address, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            MemoryShouldBe(address, value, width, signed, timeout, machine, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldNotBeEqual(ulong address, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(MemoryShouldNotBeEqual)} without setting `signed=true`");
            }
            MemoryShouldBe(address, (ulong)value, width, signed, timeout, machine, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyNotBeEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldIndependentlyBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyNotBeEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldIndependentlyNotBeEqual)} without setting `signed=true`");
            }
            AllSymbolsShouldIndependentlyBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeLessThan(ulong address, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            MemoryShouldBe(address, value, width, signed, timeout, machine, pauseEmulation, ComparisonType.LessThan);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeLessThan(ulong address, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(MemoryShouldBeLessThan)} without setting `signed=true`");
            }
            MemoryShouldBe(address, (ulong)value, width, signed, timeout, machine, pauseEmulation, ComparisonType.LessThan);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeLessThan(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldIndependentlyBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessThan);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeLessThan(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldIndependentlyBeLessThan)} without setting `signed=true`");
            }
            AllSymbolsShouldIndependentlyBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessThan);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeLessOrEqual(ulong address, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            MemoryShouldBe(address, value, width, signed, timeout, machine, pauseEmulation, ComparisonType.LessOrEqual);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeLessOrEqual(ulong address, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(MemoryShouldBeLessOrEqual)} without setting `signed=true`");
            }
            MemoryShouldBe(address, (ulong)value, width, signed, timeout, machine, pauseEmulation, ComparisonType.LessOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeLessOrEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldIndependentlyBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeLessOrEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldIndependentlyBeLessOrEqual)} without setting `signed=true`");
            }
            AllSymbolsShouldIndependentlyBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessOrEqual);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeGreaterThan(ulong address, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            MemoryShouldBe(address, value, width, signed, timeout, machine, pauseEmulation, ComparisonType.GreaterThan);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeGreaterThan(ulong address, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(MemoryShouldBeGreaterThan)} without setting `signed=true`");
            }
            MemoryShouldBe(address, (ulong)value, width, signed, timeout, machine, pauseEmulation, ComparisonType.GreaterThan);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeGreaterThan(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldIndependentlyBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterThan);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeGreaterThan(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldIndependentlyBeGreaterThan)} without setting `signed=true`");
            }
            AllSymbolsShouldIndependentlyBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterThan);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeGreaterOrEqual(ulong address, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            MemoryShouldBe(address, value, width, signed, timeout, machine, pauseEmulation, ComparisonType.GreaterOrEqual);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeGreaterOrEqual(ulong address, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(MemoryShouldBeGreaterOrEqual)} without setting `signed=true`");
            }
            MemoryShouldBe(address, (ulong)value, width, signed, timeout, machine, pauseEmulation, ComparisonType.GreaterOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeGreaterOrEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldIndependentlyBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeGreaterOrEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldIndependentlyBeGreaterOrEqual)} without setting `signed=true`");
            }
            AllSymbolsShouldIndependentlyBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterOrEqual);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            SymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(SymbolShouldBeEqual)} without setting `signed=true`");
            }
            SymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldNotBeEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            SymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldNotBeEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(SymbolShouldNotBeEqual)} without setting `signed=true`");
            }
            SymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeLessThan(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            SymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessThan);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeLessThan(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(SymbolShouldBeLessThan)} without setting `signed=true`");
            }
            SymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessThan);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeLessOrEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            SymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessOrEqual);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeLessOrEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(SymbolShouldBeLessOrEqual)} without setting `signed=true`");
            }
            SymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessOrEqual);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeGreaterThan(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            SymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterThan);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeGreaterThan(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(SymbolShouldBeGreaterThan)} without setting `signed=true`");
            }
            SymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterThan);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeGreaterOrEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            SymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterOrEqual);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeGreaterOrEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(SymbolShouldBeGreaterOrEqual)} without setting `signed=true`");
            }
            SymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldBeEqual)} without setting `signed=true`");
            }
            AllSymbolsShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldNotBeEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldNotBeEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldNotBeEqual)} without setting `signed=true`");
            }
            AllSymbolsShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeLessThan(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessThan);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeLessThan(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldBeLessThan)} without setting `signed=true`");
            }
            AllSymbolsShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessThan);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeLessOrEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeLessOrEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldBeLessOrEqual)} without setting `signed=true`");
            }
            AllSymbolsShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeGreaterThan(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterThan);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeGreaterThan(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldBeGreaterThan)} without setting `signed=true`");
            }
            AllSymbolsShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterThan);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeGreaterOrEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeGreaterOrEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AllSymbolsShouldBeGreaterOrEqual)} without setting `signed=true`");
            }
            AllSymbolsShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AnySymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AnySymbolShouldBeEqual)} without setting `signed=true`");
            }
            AnySymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldNotBeEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AnySymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldNotBeEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AnySymbolShouldNotBeEqual)} without setting `signed=true`");
            }
            AnySymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeLessThan(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AnySymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessThan);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeLessThan(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AnySymbolShouldBeLessThan)} without setting `signed=true`");
            }
            AnySymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessThan);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeLessOrEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AnySymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeLessOrEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AnySymbolShouldBeLessOrEqual)} without setting `signed=true`");
            }
            AnySymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.LessOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeGreaterThan(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AnySymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterThan);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeGreaterThan(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AnySymbolShouldBeGreaterThan)} without setting `signed=true`");
            }
            AnySymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterThan);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeGreaterOrEqual(string name, ulong value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AnySymbolShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterOrEqual);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeGreaterOrEqual(string name, long value, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            if(value <= 0 && !signed)
            {
                throw new KeywordException($"Negative value was given to {nameof(AnySymbolShouldBeGreaterOrEqual)} without setting `signed=true`");
            }
            AnySymbolShouldBe(name, (ulong)value, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.GreaterOrEqual);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeZero(ulong address, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            MemoryShouldBe(address, 0, width, signed, timeout, machine, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeZero(string name, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldIndependentlyBe(name, 0, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeZero(string name, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            SymbolShouldBe(name, 0, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeZero(string name, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldBe(name, 0, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeZero(string name, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AnySymbolShouldBe(name, 0, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.Equal);
        }

        [RobotFrameworkKeyword]
        public void MemoryShouldBeNonZero(ulong address, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, float? timeout = null, string? machine = null, bool pauseEmulation = false)
        {
            MemoryShouldBe(address, 0, width, signed, timeout, machine, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldIndependentlyBeNonZero(string name, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldIndependentlyBe(name, 0, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void SymbolShouldBeNonZero(string name, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            SymbolShouldBe(name, 0, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void AllSymbolsShouldBeNonZero(string name, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AllSymbolsShouldBe(name, 0, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        [RobotFrameworkKeyword]
        public void AnySymbolShouldBeNonZero(string name, SysbusAccessWidth width = SysbusAccessWidth.DoubleWord, bool signed = false, long offset = 0, float? timeout = null, string? machine = null, string? context = null, bool pauseEmulation = false)
        {
            AnySymbolShouldBe(name, 0, width, signed, offset, timeout, machine, context, pauseEmulation, ComparisonType.NotEqual);
        }

        private void SymbolShouldBe(string name, ulong value, SysbusAccessWidth width, bool signed, long offset, float? timeout, string? machine, string? context, bool pauseEmulation, ComparisonType compType)
        {
            SymbolsShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, compType, SymbolLookupMode.Single);
        }

        private void AllSymbolsShouldBe(string name, ulong value, SysbusAccessWidth width, bool signed, long offset, float? timeout, string? machine, string? context, bool pauseEmulation, ComparisonType compType)
        {
            SymbolsShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, compType, SymbolLookupMode.All);
        }

        private void AnySymbolShouldBe(string name, ulong value, SysbusAccessWidth width, bool signed, long offset, float? timeout, string? machine, string? context, bool pauseEmulation, ComparisonType compType)
        {
            SymbolsShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, compType, SymbolLookupMode.Any);
        }

        private void AllSymbolsShouldIndependentlyBe(string name, ulong value, SysbusAccessWidth width, bool signed, long offset, float? timeout, string? machine, string? context, bool pauseEmulation, ComparisonType compType)
        {
            SymbolsShouldBe(name, value, width, signed, offset, timeout, machine, context, pauseEmulation, compType, SymbolLookupMode.AllIndependently);
        }
    }
}
