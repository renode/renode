//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.Core.USB;
using Antmicro.Renode.Core.USB.CDC;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Extensions.Utilities.USBIP;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.CPU;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Integrations
{
    public static class ArduinoLoaderExtensions
    {
        public static void CreateArduinoLoader(this USBIPServer server, CortexM cpu, ulong binaryLoadAddress = 0x10000, int? port = null, string name = null)
        {
            var loader = new ArduinoLoader(cpu, binaryLoadAddress);
            server.Register(loader, port);

            var emulation = EmulationManager.Instance.CurrentEmulation;
            emulation.ExternalsManager.AddExternal(loader, name ?? "arduinoLoader");
        }
    }

    public class ArduinoLoader : IUSBDevice, IExternal
    {
        public ArduinoLoader(CortexM cpu, ulong binaryLoadAddress = 0x10000)
        {
            USBEndpoint interruptEndpoint = null;

            this.cpu = cpu;
            this.machine = cpu.GetMachine();
            this.binaryLoadAddress = binaryLoadAddress;

            USBCore = new USBDeviceCore(this,
                                        classCode: USBClassCode.CommunicationsCDCControl,
                                        maximalPacketSize: PacketSize.Size16,
                                        vendorId: 0x2341,
                                        productId: 0x805a,
                                        deviceReleaseNumber: 0x0100)
                .WithConfiguration(configure: c => c
                    .WithInterface(new Antmicro.Renode.Core.USB.CDC.Interface(this,
                                                    identifier: 0,
                                                    subClassCode: 0x2,
                                                    protocol: 0x1,
                                                    descriptors: new[] {
                                                        new FunctionalDescriptor(CdcFunctionalDescriptorType.Interface, CdcFunctionalDescriptorSubtype.Header, 0x10, 0x01),
                                                        new FunctionalDescriptor(CdcFunctionalDescriptorType.Interface, CdcFunctionalDescriptorSubtype.CallManagement, 0x01, 0x01),
                                                        new FunctionalDescriptor(CdcFunctionalDescriptorType.Interface, CdcFunctionalDescriptorSubtype.AbstractControlManagement, 0x02),
                                                        new FunctionalDescriptor(CdcFunctionalDescriptorType.Interface, CdcFunctionalDescriptorSubtype.Union, 0x00, 0x01)
                                                    })
                                   .WithEndpoint(Direction.DeviceToHost,
                                                 EndpointTransferType.Interrupt,
                                                 maximumPacketSize: 0x08,
                                                 interval: 0x0a,
                                                 createdEndpoint: out interruptEndpoint))
                    .WithInterface(new USBInterface(this,
                                                    identifier: 1,
                                                    classCode: USBClassCode.CDCData,
                                                    subClassCode: 0x0,
                                                    protocol: 0x0)
                                   .WithEndpoint(id: 2,
                                                 direction: Direction.HostToDevice,
                                                 transferType: EndpointTransferType.Bulk,
                                                 maximumPacketSize: 0x20,
                                                 interval: 0x0,
                                                 createdEndpoint: out hostToDeviceEndpoint)
                                   .WithEndpoint(id: 3,
                                                 direction: Direction.DeviceToHost,
                                                 transferType: EndpointTransferType.Bulk,
                                                 maximumPacketSize: 0x20,
                                                 interval: 0x0,
                                                 createdEndpoint: out deviceToHostEndpoint)));

            // when asked, say that nothing interesting happened
            interruptEndpoint.NonBlocking = true;
            deviceToHostEndpoint.NonBlocking = true;
            hostToDeviceEndpoint.DataWritten += HandleData;

            sramBuffer = new byte[BufferSize];
            flashBuffer = new byte[BufferSize];

            binarySync = new AutoResetEvent(false);
        }

        public string WaitForBinary(int timeoutInSeconds, bool autoConnect = false, int port = 0)
        {
            if(autoConnect)
            {
                SudoTools.EnsureSudoExecute($"usbip attach -r 127.0.0.1 -b 1-{port}");
            }

            if(!binarySync.WaitOne(timeoutInSeconds * 1000))
            {
                throw new RecoverableException("Received no binary in the selected time window!");
            }

            machine.SystemBus.WriteBytes(flashBuffer, binaryLoadAddress, binaryLength, context: cpu);
            cpu.VectorTableOffset = (uint)binaryLoadAddress;

            return $"Binary of size {binaryLength} bytes loaded at 0x{binaryLoadAddress:X}";
        }

        public void Reset()
        {
            USBCore.Reset();

            Array.Clear(sramBuffer, 0, sramBuffer.Length);
            Array.Clear(flashBuffer, 0, flashBuffer.Length);

            flashOffset = 0;
            sramReadOffset = 0;
            sramWriteOffset = 0;

            sramBytesLeft = 0;
            binaryLength = 0;

            binarySync.Reset();
        }

        public USBDeviceCore USBCore { get; }

        private void HandleData(byte[] input)
        {
            if(sramBytesLeft > 0)
            {
                StoreToSRAMBuffer(input);
            }
            else
            {
                Decode(input);
            }
        }

        private void Decode(byte[] d)
        {
            this.Log(LogLevel.Noisy, "Decoding input: {0}", System.Text.ASCIIEncoding.ASCII.GetString(d));

            uint value = 0;
            uint savedValue = 0;
            var command = Command.None;

            for(var i = 0; i < d.Length; i++)
            {
                if(d[i] >= '0' && d[i] <= '9')
                {
                    AppendNibble(ref value, (byte)(d[i] - '0'));
                }
                else if(d[i] >= 'a' && d[i] <= 'f')
                {
                    AppendNibble(ref value, (byte)(d[i] - 'a'));
                }
                else if(d[i] >= 'A' && d[i] <= 'F')
                {
                    AppendNibble(ref value, (byte)(d[i] - 'A'));
                }
                else
                {
                    switch((char)d[i])
                    {
                    case '#': // End of command
                        HandleCommand((Command)command, savedValue, value);
                        savedValue = 0;
                        value = 0;
                        break;

                    case (char)Command.DumpSRAMBufferToFLASH:
                    case (char)Command.SetSRAMBuffer:
                    case (char)Command.GetHWInfo:
                    case (char)Command.SwitchToNonInteractiveMode:
                    case (char)Command.GetSWVersion:
                    case (char)Command.EraseFlash:
                    case (char)Command.ExecuteLoadedApp:
                    case (char)Command.WriteByte:
                    case (char)Command.WriteWord:
                    case (char)Command.WriteDoubleWord:
                        command = (Command)d[i];
                        break;

                    case ',':
                        savedValue = value;
                        value = 0;
                        break;

                    default:
                        this.Log(LogLevel.Warning, "Unknown command {0} (0x{0:X})", (Command)d[i]);
                        return;
                    }
                }
            }
        }

        private void HandleCommand(Command c, uint arg0, uint arg1)
        {
            this.Log(LogLevel.Noisy, "Handling command {0} (0x{0:X}) with args [0]: 0x{1:X} [1]: 0x{2:X}", c, arg0, arg1);

            switch(c)
            {
            case Command.SetSRAMBuffer:
            {
                sramWriteOffset = arg0;
                sramBytesLeft = arg1;

                // no response
                break;
            }

            case Command.DumpSRAMBufferToFLASH:
            {
                if(arg1 != 0)
                {
                    CopyFromSRAMToFlash(arg1);
                }
                else
                {
                    sramReadOffset = arg0;
                }

                SendResponse("Y");
                break;
            }

            case Command.ExecuteLoadedApp:
            {
                binarySync.Set();

                // no response
                break;
            }

            case Command.SwitchToNonInteractiveMode:
                SendResponse(string.Empty);
                break;

            case Command.GetSWVersion:
                SendResponse("Arduino Bootloader (SAM-BA extended) 2.0 [Arduino:IKXYZ]");
                break;

            case Command.GetHWInfo:
                SendResponse("nRF52840-QIAA");
                break;

            case Command.EraseFlash:
                Array.Clear(flashBuffer, 0, flashBuffer.Length);
                SendResponse("X");
                break;

            case Command.WriteByte:
                machine.SystemBus.WriteByte(arg0, (byte)arg1);
                break;

            case Command.WriteWord:
                machine.SystemBus.WriteWord(arg0, (ushort)arg1);
                break;

            case Command.WriteDoubleWord:
                machine.SystemBus.WriteDoubleWord(arg0, arg1);
                break;

            default:
                this.Log(LogLevel.Warning, "Unsupported command {0} (0x{0:X})", c);
                break;
            }
        }

        private void SendResponse(string s)
        {
            deviceToHostEndpoint.HandlePacket(System.Text.ASCIIEncoding.ASCII.GetBytes(s + "\n\r"));
        }

        private void AppendNibble(ref uint val, byte b)
        {
            val <<= 4;
            val |= b & 0xFu;
        }

        private void StoreToSRAMBuffer(byte[] d)
        {
            var len = (uint)d.Length;
            if(sramWriteOffset + d.Length > sramBuffer.Length)
            {
                len = (uint)sramBuffer.Length - sramWriteOffset;
                this.Log(LogLevel.Warning, "Received {0} bytes of data to store in the SRAM buffer, but there is space only for {1}. Ignoring the rest - it can cause problems!", d.Length, len);
            }

            for(var i = 0; i < len; i++)
            {
                sramBuffer[sramWriteOffset + i] = d[i];
            }
            sramBytesLeft -= len;
            sramWriteOffset += len;
        }

        private void CopyFromSRAMToFlash(uint len)
        {
            if(flashOffset + len > flashBuffer.Length)
            {
                var origLen = len;
                len = (uint)flashBuffer.Length - flashOffset;
                this.Log(LogLevel.Warning, "Asked to write {0} bytes to flash buffer, but there is space only for {1}. Ignoring the rest - it can cause problems!", len, origLen);
            }

            for(var i = 0; i < len; i++)
            {
                flashBuffer[flashOffset + i] = sramBuffer[sramReadOffset + i];
            }
            flashOffset += len;
            binaryLength += len;
        }

        private uint flashOffset;
        private uint sramWriteOffset;
        private uint sramReadOffset;

        private uint sramBytesLeft;
        private uint binaryLength;

        private USBEndpoint hostToDeviceEndpoint;
        private USBEndpoint deviceToHostEndpoint;

        private readonly byte[] sramBuffer;
        private readonly byte[] flashBuffer;

        private readonly AutoResetEvent binarySync;
        private readonly CortexM cpu;
        private readonly IMachine machine;
        private readonly ulong binaryLoadAddress;

        private const int BufferSize = 0xf0000;

        private enum Command : byte
        {
            None = 0,

            DumpSRAMBufferToFLASH = (byte)'Y',
            SetSRAMBuffer = (byte)'S',
            GetHWInfo = (byte)'I',
            SwitchToNonInteractiveMode = (byte)'N',
            GetSWVersion = (byte)'V',
            EraseFlash = (byte)'X',
            ExecuteLoadedApp = (byte)'K',
            WriteByte = (byte)'O',
            WriteWord = (byte)'H',
            WriteDoubleWord = (byte)'W',
        }
    }
}