//
// Copyright (c) 2010-2022 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Reflection;
using Antmicro.Renode.Core;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Debug
{
    public static class SeL4Extensions
    {
        public static void CreateSeL4(this ICpuSupportingGdb @this, ulong? debugThreadNameSyscallId = null)
        {
            EmulationManager.Instance.CurrentEmulation.ExternalsManager.AddExternal(new SeL4DebugHelper(@this, debugThreadNameSyscallId), "seL4");
        }
    }

    public class SeL4DebugHelper : IExternal
    {
        public SeL4DebugHelper(ICpuSupportingGdb cpu, ulong? debugThreadNameSyscallId)
        {
            if(cpu is Arm)
            {
                this.callingConvention = new ArmCallingConvention(cpu);
            }
            else if(cpu is RiscV32)
            {
                this.callingConvention = new RiscVCallingConvention(cpu);
            }
            else
            {
                throw new RecoverableException("Only ARM and RV32 based platforms are supported by the seL4 extension");
            }

            this.debugThreadNameSyscall = debugThreadNameSyscallId ?? DefaultDebugThreadNameSyscall;

            this.cpu = cpu;
            this.mapping = new Dictionary<ulong, string>();
            this.breakpoints = new Dictionary<ulong, HashSet<string>>();
            this.temporaryBreakpoints = new Dictionary<ulong, HashSet<string>>();

            // Save restore_user_context as we will be using it pretty often
            this.restoreUserContextAddress = cpu.Bus.GetSymbolAddress("restore_user_context");

            // handleUnknownSyscall function is handling seL4_DebugThreadName syscall.
            // We are using this hook to inspect thread's TCB after it was initialized
            var handleUnknownSyscallAddress = cpu.Bus.GetSymbolAddress("handleUnknownSyscall");
            this.cpu.AddHook(handleUnknownSyscallAddress, HandleUnknownSyscall);
            // When everything is set up and none of threads is working, this function will be called
            // It seems to be always called after initialization of all CAmkES components
            // so we can use it to check "readiness".
            var idleThreadAddresss = cpu.Bus.GetSymbolAddress("idle_thread");
            this.cpu.AddHook(idleThreadAddresss, Finalize);
        }

        public string CurrentThread()
        {
            if(callingConvention.PrivilegeMode == PrivilegeMode.Supervisor)
            {
                return "kernel";
            }
            return CurrentThreadUnsafe();
        }

        public void BreakOnNamingThread(string threadName)
        {
            pendingThreadName = threadName;
        }

        public void BreakOnExittingUserspace(ExitUserspaceMode mode)
        {
            if(mode == exitUserspaceMode)
            {
                return;
            }

            if(exitUserspaceMode == ExitUserspaceMode.Never)
            {
                cpu.AddHook(callingConvention.SyscallTrapAddress, HandleExitUserspace);
            }
            else if(mode == ExitUserspaceMode.Never)
            {
                cpu.RemoveHook(callingConvention.SyscallTrapAddress, HandleExitUserspace);
            }

            exitUserspaceMode = mode;
        }

        // Sets the breakpoint on given address in chosen thread
        // If address is not given, the breakpoint is set right after
        // on the first instruction after context switch
        public void SetBreakpoint(string threadName, ulong address = WildcardAddress)
        {
            SetBreakpointHelper(threadName, address, breakpoints);
        }

        // Similiar to SetBreakpoint, but for temporary breakpoints
        public void SetTemporaryBreakpoint(string threadName, ulong address = WildcardAddress)
        {
            SetBreakpointHelper(threadName, address, temporaryBreakpoints);
        }

        // Removes existing breakpoint on given address in chosen thread
        // If address is not given, then breakpoint which happens on context switch
        // is removed (see SetBreakpoint). If removeAll is set to true, all breakpoints for
        // given thread are removed.
        public void RemoveBreakpoint(string threadName, ulong address = WildcardAddress)
        {
            RemoveBreakpointHelper(threadName, address, breakpoints);
        }

        public void RemoveTemporaryBreakpoint(string threadName, ulong address = WildcardAddress)
        {
            RemoveBreakpointHelper(threadName, address, temporaryBreakpoints);
        }

        public void RemoveAllBreakpoints(string threadName = null)
        {
            string realThreadName = null;
            if(threadName != null && !TryGetRealThreadName(threadName, out realThreadName))
            {
                return;
            }

            foreach(var item in breakpoints.ToList())
            {
                if(realThreadName != null)
                {
                    item.Value.Remove(realThreadName);
                }
                if(realThreadName == null || item.Value.Count == 0)
                {
                    breakpoints.Remove(item.Key);
                }
                if(GetBreakpointsCount(item.Key) == 0)
                {
                    RemoveHook(item.Key);
                }
            }
            foreach(var item in temporaryBreakpoints.ToList())
            {
                if(realThreadName != null)
                {
                    item.Value.Remove(realThreadName);
                }
                if(realThreadName == null || item.Value.Count == 0)
                {
                    temporaryBreakpoints.Remove(item.Key);
                }
                if(GetBreakpointsCount(item.Key) == 0)
                {
                    RemoveHook(item.Key);
                }
            }
        }

        // Returns table with all the breakpoints. If threadName is set,
        // returns only breakpoints set in given thread.
        public string[,] GetBreakpoints(string threadName = null)
        {
            var entries = breakpoints.SelectMany(t => t.Value, (entry, thread) => new { Thread = thread, Address = entry.Key, Temporary = false })
                .Concat(temporaryBreakpoints.SelectMany(t => t.Value, (entry, thread) => new { Thread = thread, Address = entry.Key, Temporary = true }));

            if(threadName != null)
            {
                entries = entries.Where(x => x.Thread.Contains(threadName));
            }
            var table = new Table().AddRow("Thread", "Address", "Temporary");
            table.AddRows(entries,
                    x => x.Thread == AnyThreadName ? "any" : x.Thread,
                    x => x.Address == WildcardAddress ? "any" : "0x{0:X}".FormatWith(x.Address),
                    x => x.Temporary.ToString());
            if(exitUserspaceMode != ExitUserspaceMode.Never)
            {
                table.AddRow("kernel", "any", (exitUserspaceMode == ExitUserspaceMode.Once).ToString());
            }
            return table.ToArray();
        }

        // Returns list of all the breakpoints in script-friendly format: <THREAD_NAME>:<ADDRESS>\n.
        // If threadName is set, returns only breakpoints set in given thread.
        public string GetBreakpointsPlain(string threadName = null)
        {
            var entries = breakpoints.SelectMany(t => t.Value, (entry, thread) => new { Thread = thread, Address = entry.Key })
                .Concat(temporaryBreakpoints.SelectMany(t => t.Value, (entry, thread) => new { Thread = thread, Address = entry.Key }));

            if(threadName != null)
            {
                entries = entries.Where(x => x.Thread.Contains(threadName));
            }
            var output = entries.Select(entry => "{0}:{1}".FormatWith(
                    entry.Thread,
                    entry.Address == WildcardAddress ? "any" : "0x{0:X}".FormatWith(entry.Address)));
            return string.Join("\n", output);
        }

        public string[] Threads => mapping.Values.ToArray();

        public bool Ready { get; private set; }

        private ulong TryTranslateAddress(ICpuSupportingGdb cpu, ulong virtualAddress)
        {
            if(cpu is ICPUWithMMU cpuWithMmu)
            {
                virtualAddress = cpuWithMmu.TranslateAddress(virtualAddress, MpuAccess.Read);
            }
            return virtualAddress;
        }

        private void HandleUnknownSyscall(ICpuSupportingGdb cpu, ulong address)
        {
            // Check if seL4_DebugThreadName was called
            if((callingConvention.FirstArgument & 0xFFFFFFFF) != debugThreadNameSyscall)
            {
                return;
            }

            // We are in seL4_DebugThreadName handler, we don't need this hook anymore
            cpu.RemoveHook(address, HandleUnknownSyscall);

            // This function will now call lookupIPCBuffer and lookupCapAndSlot
            // We can temporarily hook those functions, and save theirs
            // return addresses (which will be somewhere in handleUnknownSyscall)
            // so we can use them later to "scrape" thread information.
            // Additionally, we are getting address of ksCurThread variable
            // which stores address of TCB of current thread.
            var ksCurThreadAddress = cpu.Bus.GetSymbolAddress("ksCurThread");
            var lookupIPCBufferAddress = cpu.Bus.GetSymbolAddress("lookupIPCBuffer");
            var lookupCapAndSlotAddress = cpu.Bus.GetSymbolAddress("lookupCapAndSlot");

            // At this point we are sure, that we are in kernel context and ksCurrThread symbol vaddr
            // will resolve properly. Therefore we can translate virtual address to physical address
            // and use it to read memory. That allow us to check current TCB no matter in which
            // context/privilege mode we are currently in, ignoring MMU completely.
            ksCurThreadPhysAddress = TryTranslateAddress(cpu, ksCurThreadAddress);
            
            cpu.AddHook(lookupCapAndSlotAddress, HandleLookupCapAndSlotAddress);
            cpu.AddHook(lookupIPCBufferAddress, HandleLookupIPCBuffer);
        }

        private void Finalize(ICpuSupportingGdb cpu, ulong address)
        {
            cpu.RemoveHook(address, Finalize);
            Ready = true;
            this.Log(LogLevel.Info, "Initialization complete.");
        }

        private void HandleRestoreUserContext(ICpuSupportingGdb cpu, ulong address)
        {
            var threadName = CurrentThreadUnsafe();
            if(!DoBreakpointExists(WildcardAddress, threadName))
            {
                return;
            }

            ulong tcbAddress = cpu.Bus.ReadDoubleWord(this.ksCurThreadPhysAddress, context: cpu);
            if(!IsValidAddress(tcbAddress))
            {
                this.Log(LogLevel.Debug, "Got invalid address for TCB, skipping");
                return;
            }

            var nextPCAddress = TryTranslateAddress(cpu, tcbAddress + callingConvention.TCBNextPCOffset);
           
            if(!IsValidAddress(nextPCAddress))
            {
                this.Log(LogLevel.Debug, "NextPC address in TCB is invalid, skipping");
                return;
            }

            var pc = cpu.Bus.ReadDoubleWord(nextPCAddress, context: cpu);
            cpu.AddHook(pc, HandleThreadSwitch);
        }

        private void HandleThreadSwitch(ICpuSupportingGdb cpu, ulong address)
        {
            var threadName = CurrentThread();
            // Remove temporary breakpoint if exists
            ClearTemporaryBreakpoint(WildcardAddress, threadName);
            // We changed context, remove this hook as we don't need it anymore
            cpu.RemoveHook(address, HandleThreadSwitch);
            cpu.Pause();
            cpu.EnterSingleStepModeSafely(new HaltArguments(HaltReason.Breakpoint, cpu.Id, address, BreakpointType.MemoryBreakpoint), true);
        }

        private void HandleBreakpoint(ICpuSupportingGdb cpu, ulong address)
        {
            var threadName = CurrentThread();
            if(!DoBreakpointExists(address, threadName))
            {
                return;
            }

            ClearTemporaryBreakpoint(address, threadName);
            cpu.Pause();
            cpu.EnterSingleStepModeSafely(new HaltArguments(HaltReason.Breakpoint, cpu.Id, address, BreakpointType.MemoryBreakpoint), true);
        }

        private void HandleExitUserspace(ICpuSupportingGdb cpu, ulong address)
        {
            if(callingConvention.PrivilegeMode != PrivilegeMode.Supervisor)
            {
                return;
            }

            cpu.Pause();
            cpu.EnterSingleStepModeSafely(new HaltArguments(HaltReason.Breakpoint, cpu.Id, address, BreakpointType.MemoryBreakpoint), true);
            if(exitUserspaceMode == ExitUserspaceMode.Once)
            {
                cpu.RemoveHook(address, HandleExitUserspace);
                exitUserspaceMode = ExitUserspaceMode.Never;
            }
        }

        private void HandleLookupCapAndSlotAddress(ICpuSupportingGdb cpu, ulong address)
        {
            // Save address to instruction in handleUnknownSyscall after call to lookupCapAndSlot
            cpu.RemoveHook(address, HandleLookupCapAndSlotAddress);
            cpu.AddHook(callingConvention.ReturnAddress, HandlePostLookupCapAndSlotAddress);
        }

        private void HandlePostLookupCapAndSlotAddress(ICpuSupportingGdb cpu, ulong address)
        {
            // Return value of lookupCapAndSlot is a structure
            // with size of two machine words. We are interested in second value
            // which is address of the capability (in this case TCB)
            var luRet = callingConvention.ReturnValue;
            var paddr = TryTranslateAddress(cpu, luRet + 0x4UL);
            var underlying = cpu.Bus.ReadDoubleWord(paddr, context: cpu);
            currentTCB = underlying & 0xffffffffffffff00;
        }

        private void HandleLookupIPCBuffer(ICpuSupportingGdb cpu, ulong address)
        {
            // Save address to instruction in handleUnknownSyscall after call to lookupIPCBuffer
            cpu.RemoveHook(address, HandleLookupIPCBuffer);
            cpu.AddHook(callingConvention.ReturnAddress, HandlePostLookupIPCBuffer);
        }

        private void HandlePostLookupIPCBuffer(ICpuSupportingGdb cpu, ulong address)
        {
            // In A0 register address to IPC buffer is returned.
            // As seL4_DebugThreadName saves pointer to the string in IPC buffer,
            // we can now just recover and read it.
            var paddr = TryTranslateAddress(cpu, callingConvention.ReturnValue + 0x4UL);
            var buffer = new List<byte>();

            // Maximum string size is MaximumMesageLength * size of machine word - 1
            for(ulong i = 0; i < MaximumMessageLength * 4 - 1; ++i)
            {
                var c = cpu.Bus.ReadByte(paddr + i, context: cpu);
                if(c == 0)
                {
                    break;
                }
                buffer.Add(c);
            }

            var threadName = System.Text.Encoding.ASCII.GetString(buffer.ToArray());

            // This function is called _after_ lookupCapAndSlot, therefore we now
            // have both TCB address and thread's name. We can add it to our list
            // of known threads.
            if(!mapping.ContainsKey(currentTCB) || threadName.Contains("_control"))
            {
                mapping[currentTCB] = threadName;
            }

            // There was pendingThreadName set by WaitForThread function. As we have now all
            // necessary information for requested thread, we can enter SingleStepMode
            // (and thus return to prompt in GDB) so user can do something with it,
            // e.g. create breakpoint on this thread.
            if(pendingThreadName != null && threadName.Contains(pendingThreadName))
            {
                pendingThreadName = null;
                cpu.Pause();
                cpu.EnterSingleStepModeSafely(new HaltArguments(HaltReason.Breakpoint, cpu.Id, address, BreakpointType.MemoryBreakpoint), true);
            }
        }

        private int GetBreakpointsCount(ulong address)
        {
            breakpoints.TryGetValue(address, out var bp);
            temporaryBreakpoints.TryGetValue(address, out var tbp);
            return (bp?.Count ?? 0) + (tbp?.Count ?? 0);
        }

        private bool TryGetRealThreadName(string threadName, out string realThreadName)
        {
            if(threadName == AnyThreadName)
            {
                realThreadName = AnyThreadName;
                return true;
            }

            realThreadName = mapping.Values.Where(thread => thread.Contains(threadName)).FirstOrDefault();
            if(String.IsNullOrEmpty(realThreadName))
            {
                this.Log(LogLevel.Warning, "No thread with name '{0}' found.", threadName);
                return false;
            }

            return true;
        }

        private bool DoBreakpointExists(ulong address, string threadName)
        {
            return (breakpoints.TryGetValue(address, out var bpList) && (bpList.Contains(AnyThreadName) || bpList.Contains(threadName))) ||
                   (temporaryBreakpoints.TryGetValue(address, out var tbpList) && (tbpList.Contains(AnyThreadName) || tbpList.Contains(threadName)));
        }

        private void AddContextSwitchHook()
        {
            cpu.AddHook(restoreUserContextAddress, HandleRestoreUserContext);
        }

        private void RemoveContextSwitchHook()
        {
            cpu.RemoveHook(restoreUserContextAddress, HandleRestoreUserContext);
        }

        private void ClearTemporaryBreakpoint(ulong address, string threadName)
        {
            if(!temporaryBreakpoints.ContainsKey(address))
            {
                return;
            }

            temporaryBreakpoints[address].Remove(threadName);
            temporaryBreakpoints[address].Remove(AnyThreadName);

            if(GetBreakpointsCount(address) == 0)
            {
                RemoveHook(address);
            }
        }

        private void SetBreakpointHelper(string threadName, ulong address, Dictionary<ulong, HashSet<string>> breakpointsSource)
        {
            if(!TryGetRealThreadName(threadName, out var realThreadName))
            {
                return;
            }

            if(!breakpointsSource.ContainsKey(address))
            {
                breakpointsSource.Add(address, new HashSet<string>());
            }

            if(!breakpointsSource[address].Add(realThreadName))
            {
                this.Log(LogLevel.Warning, "This breakpoint already exists.");
                return;
            }

            var breakpointsNum = GetBreakpointsCount(address);

            // Ignore if we already registered breakpoint for this address
            if(breakpointsNum != 1)
            {
                return;
            }

            AddHook(address);
        }

        private void RemoveBreakpointHelper(string threadName, ulong address, Dictionary<ulong, HashSet<string>> breakpointsSource)
        {
            if(!breakpointsSource.TryGetValue(address, out var breakpoint))
            {
                return;
            }

            if(!TryGetRealThreadName(threadName, out var realThreadName))
            {
                return;
            }

            breakpoint.Remove(realThreadName);
            var breakpointsNum = GetBreakpointsCount(address);
            if(breakpointsNum != 0)
            {
                return;
            }

            RemoveHook(address);
        }

        private void AddHook(ulong address)
        {
            if(address != WildcardAddress)
            {
                cpu.AddHook(address, HandleBreakpoint);
            }
            else
            {
                AddContextSwitchHook();
            }
        }

        private void RemoveHook(ulong address)
        {
            if(address != WildcardAddress)
            {
                cpu.RemoveHook(address, HandleBreakpoint);
            }
            else
            {
                RemoveContextSwitchHook();
            }
        }

        private bool IsValidAddress(ulong address)
        {
            return !(address == 0x00000000 || address == 0xFFFFFFFF);
        }

        private string CurrentThreadUnsafe()
        {
            var tcb = cpu.Bus.ReadDoubleWord(this.ksCurThreadPhysAddress, context: cpu);
            if(mapping.ContainsKey(tcb))
            {
                return mapping[tcb];
            }
            return "unknown";
        }

        public enum ExitUserspaceMode
        {
            Never,
            Once,
            Always,
        }

        private const uint DefaultDebugThreadNameSyscall = 0xfffffff2;
        private const string AnyThreadName = "<any>";
        private const uint WildcardAddress = 0x00000000;
        private const uint MaximumMessageLength = 120;

        private readonly Dictionary<ulong, HashSet<string>> breakpoints;
        private readonly Dictionary<ulong, HashSet<string>> temporaryBreakpoints;
        private readonly Dictionary<ulong, string> mapping;
        private readonly ICpuSupportingGdb cpu;
        private readonly ICallingConvention callingConvention;
        private readonly ulong debugThreadNameSyscall;

        private ExitUserspaceMode exitUserspaceMode;
        private bool breakpointsEnabled;
        private ulong ksCurThreadPhysAddress;
        private ulong restoreUserContextAddress;
        private string pendingThreadName;
        private ulong currentTCB;

        private interface ICallingConvention
        {
            ulong FirstArgument { get; }
            ulong ReturnValue { get; }
            ulong ReturnAddress { get; }
            ulong SyscallTrapAddress { get; }
            ulong TCBNextPCOffset { get; }
            PrivilegeMode PrivilegeMode { get; }
        }

        private enum PrivilegeMode
        {
            Userspace,
            Supervisor,
            Other,
        }

        private class RiscVCallingConvention : ICallingConvention
        {
            public RiscVCallingConvention(ICpuSupportingGdb cpu)
            {
                this.cpu = cpu;
                // Assumes that symbols for kernel are loaded
                syscallTrapAddress = cpu.Bus.GetSymbolAddress("trap_entry");
            }

            public ulong FirstArgument => cpu.A[0];
            public ulong ReturnValue => cpu.A[0];
            public ulong ReturnAddress => cpu.RA;
            public ulong SyscallTrapAddress => syscallTrapAddress;
            public PrivilegeMode PrivilegeMode
            {
                get
                {
                    switch((byte)cpu.PRIV)
                    {
                        case 0b00:
                            return PrivilegeMode.Userspace;
                        case 0b01:
                            return PrivilegeMode.Supervisor;
                        default:
                            return PrivilegeMode.Other;
                    }
                }
            }
            public ulong TCBNextPCOffset => 34 * 4;

            private readonly ulong syscallTrapAddress;
            private readonly dynamic cpu;
        }

        private class ArmCallingConvention : ICallingConvention
        {
            public ArmCallingConvention(ICpuSupportingGdb cpu)
            {
                this.cpu = (Arm)cpu;
                // Assumes that symbols for kernel are loaded
                syscallTrapAddress = cpu.Bus.GetSymbolAddress("arm_swi_syscall");
            }

            public ulong FirstArgument => cpu.R[0];
            public ulong ReturnValue => cpu.R[0];
            public ulong ReturnAddress => cpu.R[14];
            public ulong SyscallTrapAddress => syscallTrapAddress;
            public PrivilegeMode PrivilegeMode
            {
                get
                {
                    switch(cpu.CPSR & 0xfUL)
                    {
                        case 0b00:
                            return PrivilegeMode.Userspace;
                        case 0b11:
                            return PrivilegeMode.Supervisor;
                        default:
                            return PrivilegeMode.Other;
                    }
                }
            }
            public ulong TCBNextPCOffset => 15 * 4;

            private readonly ulong syscallTrapAddress;
            private readonly Arm cpu;
        }
    }
}

