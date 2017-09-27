/**************************************************************************
*                           MIT License
*
* Copyright (C) 2015 Frederic Chaxel <fchaxel@free.fr>
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be included
* in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*
*********************************************************************/
using System;
using System.Runtime.InteropServices;
using System.IO;
using System.Diagnostics;
using System.IO.Pipes;

namespace Antmicro.Renode.Plugins.WiresharkPlugin
{
    public class WiresharkSender
    {
        public WiresharkSender(string pipeName, UInt32 pcapNetId, string wiresharkPath)
        {
            this.pipeName = pipeName;
            this.pcapNetId = pcapNetId;
            this.wiresharkPath = wiresharkPath;
        }

        private void PipeCreate()
        {
            wiresharkPipe = new NamedPipeServerStream(pipeName, PipeDirection.Out, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
            lastReportedFrame = null;
        }

        public void WiresharkGlobalHeader()
        {
            var p = new PcapGlobalHeader(65535, pcapNetId);
            var bh = p.ToByteArray();
            wiresharkPipe.Write(bh, 0, bh.Length);
        }

        public void ClearPipe()
        {
            wiresharkPipe.Close();
#if !EMUL8_PLATFORM_WINDOWS
            File.Delete($"{NamedPipePrefix}{pipeName}");
#endif
        }
        public bool IsConnected
        {
            get { return isConnected; }
        }

        public bool TryOpenWireshark()
        {
            if(IsConnected)
            {
                return false;
            }

            PipeCreate();
            wiresharkProces = new Process();
            wiresharkProces.EnableRaisingEvents = true;

            var arguments = $"-ni {NamedPipePrefix}{pipeName} -k";
            wiresharkProces.StartInfo = new ProcessStartInfo(wiresharkPath, arguments)
            {
                UseShellExecute = false,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                RedirectStandardInput = true
            };
            wiresharkProces.Exited += (sender, e) =>
            {
                isConnected = false;
                ClearPipe();
            };

            wiresharkProces.Start();
            wiresharkPipe.WaitForConnection();
            isConnected = true;
            WiresharkGlobalHeader();

            return true;
        }

        public void CloseWireshark()
        {
            if(wiresharkProces == null)
            {
                return;
            }

            try
            {
                if(!wiresharkProces.HasExited)
                {
                    wiresharkProces.CloseMainWindow();
                }
            }
            catch(InvalidOperationException e)
            {
                // do not report an exception if the program has already exited
                if(!e.Message.Contains("finished"))
                {
                    throw;
                }
            }
            wiresharkProces = null;
        }

        public void SendReportedFrames(byte[] buffer)
        {
            if(lastReportedFrame != buffer)
            {
                SendToWireshark(buffer, 0, buffer.Length);
                lastReportedFrame = buffer;
            }
        }

        public void SendProcessedFrames(byte[] buffer)
        {
            if(lastProcessedFrame != buffer)
            {
                SendToWireshark(buffer, 0, buffer.Length);
                lastProcessedFrame = buffer;
            }
        }

        private UInt32 DateTimeToUnixTimestamp(DateTime dateTime)
        {
            return (UInt32)(dateTime - new DateTime(1970, 1, 1).ToLocalTime()).TotalSeconds;
        }

        private bool SendToWireshark(byte[] buffer, int offset, int lenght)
        {
            return SendToWireshark(buffer, offset, lenght, DateTime.Now);
        }

        private bool SendToWireshark(byte[] buffer, int offset, int lenght, DateTime date)
        {
            UInt32 date_sec, date_usec;

            // Suppress all values for ms, us and ns
            var d2 = new DateTime((date.Ticks / (long)10000000) * (long)10000000);

            date_sec = DateTimeToUnixTimestamp(date);
            date_usec = (UInt32)((date.Ticks - d2.Ticks) / 10);

            return SendToWireshark(buffer, offset, lenght, date_sec, date_usec);
        }

        private bool SendToWireshark(byte[] buffer, int offset, int lenght, UInt32 date_sec, UInt32 date_usec)
        {
            if(!isConnected)
            {
                return false;
            }

            var pHdr = new PcapPacketHeader((UInt32)lenght, date_sec, date_usec);
            var b = pHdr.ToByteArray();

            try
            {
                // Wireshark Header
                wiresharkPipe.Write(b, 0, b.Length);

                // Bacnet packet
                wiresharkPipe.Write(buffer, offset, lenght);

            }
            catch(IOException)
            {
                return false;
            }
            catch(Exception)
            {
                // Unknow error, not due to the pipe
                // No need to restart it
                return false;
            }

            return true;
        }

        private NamedPipeServerStream wiresharkPipe;
        private Process wiresharkProces;
        private bool isConnected = false;
        private string pipeName;
        private UInt32 pcapNetId;
        private string wiresharkPath;
        private byte[] lastReportedFrame;
        private byte[] lastProcessedFrame;

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        struct PcapPacketHeader
        {
            UInt32 ts_sec;
            /* timestamp seconds */
            UInt32 ts_usec;
            /* timestamp microseconds */
            UInt32 incl_len;
            /* number of octets of packet saved in file */
            UInt32 orig_len;
            /* actual length of packet */

            public PcapPacketHeader(UInt32 lenght, UInt32 datetime, UInt32 microsecond)
            {
                incl_len = orig_len = lenght;
                ts_sec = datetime;
                ts_usec = microsecond;
            }

            // struct Marshaling
            // Maybe a 'manual' byte by byte serialise could be required on some system
            public byte[] ToByteArray()
            {
                var rawsize = Marshal.SizeOf(this);
                var rawdatas = new byte[rawsize];
                var handle = GCHandle.Alloc(rawdatas, GCHandleType.Pinned);
                var buffer = handle.AddrOfPinnedObject();
                Marshal.StructureToPtr(this, buffer, false);
                handle.Free();
                return rawdatas;
            }
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        struct PcapGlobalHeader
        {
            UInt32 magic_number;
            /* magic number */
            UInt16 version_major;
            /* major version number */
            UInt16 version_minor;
            /* minor version number */
            Int32 thiszone;
            /* GMT to local correction */
            UInt32 sigfigs;
            /* accuracy of timestamps */
            UInt32 snaplen;
            /* max length of captured packets, in octets */
            UInt32 network;
            /* data link type */

            public PcapGlobalHeader(UInt32 snaplen, UInt32 network)
            {
                magic_number = 0xa1b2c3d4;
                version_major = 2;
                version_minor = 4;
                thiszone = 0;
                sigfigs = 0;
                this.snaplen = snaplen;
                this.network = network;
            }

            // struct Marshaling
            // Maybe a 'manual' byte by byte serialization could be required on some systems
            // work well on Win32, Win64 .NET 3.0 to 4.5
            public byte[] ToByteArray()
            {
                var rawsize = Marshal.SizeOf(this);
                var rawdatas = new byte[rawsize];
                var handle = GCHandle.Alloc(rawdatas, GCHandleType.Pinned);
                var buffer = handle.AddrOfPinnedObject();
                Marshal.StructureToPtr(this, buffer, false);
                handle.Free();
                return rawdatas;
            }
        }

#if !EMUL8_PLATFORM_WINDOWS
        private const string NamedPipePrefix = "/var/tmp/";
#else
        private const string NamedPipePrefix = @"\\.\pipe\";
#endif
    }
}
