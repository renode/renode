//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Linq;
using System.Threading;

using Antmicro.Renode.Core;
using Antmicro.Renode.Core.Structure.Registers;
using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Peripherals
{
    public class UnsafePeripheral : BasicDoubleWordPeripheral, IKnownSize
    {
        public UnsafePeripheral(Machine machine) : base(machine)
        {
            Registers.Base.Define(this)
                .WithValueField(0, 32, out value, FieldMode.Write, writeCallback: (_, val) =>
                {
                    if(val.ToString() != IntToString((int)val))
                    {
                        // Modify the value to fail the test.
                        value.Value = val + 1;
                    }

                    // Create two arrays of the same length.
                    int length = 100;
                    byte[] byteArray1 = new byte[length];
                    byte[] byteArray2 = new byte[length];

                    // Fill byteArray1 with 0 - 99.
                    for(int i = 0; i < length; ++i)
                    {
                        byteArray1[i] = (byte)i;
                    }

                    // Copy the contents of byteArray1 to byteArray2.
                    Copy(byteArray1, 0, byteArray2, 0, length);

                    if(byteArray2[8] != byteArray1[8])
                    {
                        // Modify the value to fail the test.
                        value.Value = val + 1;
                    }

                    // Copy the contents of the last 10 elements of byteArray1 to the beginning of byteArray2.
                    // The offset specifies where the copying begins in the source array.
                    int offset = length - 10;
                    Copy(byteArray1, offset, byteArray2, 0, length - offset);
                    if(byteArray2[0] != byteArray1[90])
                    {
                        // Modify the value to fail the test.
                        value.Value = val + 1;
                    }
                });

            Registers.Multiplier.Define(this)
                .WithValueField(0, 32, FieldMode.Read, valueProviderCallback: _ => value.Value * 2);

            Registers.BitCounter.Define(this)
                .WithValueField(0, 32, FieldMode.Read, valueProviderCallback: _ => (uint)BitHelper.GetBits(value.Value).Where(x => x).Select(x => 1).Sum(x => x));
        }

        // https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/unsafe-code#how-to-use-pointers-to-copy-an-array-of-bytes
        private static unsafe void Copy(byte[] source, int sourceOffset, byte[] target,
            int targetOffset, int count)
        {
            // If either array is not instantiated, you cannot complete the copy.
            if((source == null) || (target == null))
            {
                throw new ArgumentException("source or target is null");
            }

            // If either offset, or the number of bytes to copy, is negative, you
            // cannot complete the copy.
            if((sourceOffset < 0) || (targetOffset < 0) || (count < 0))
            {
                throw new ArgumentException("offset or bytes to copy is negative");
            }

            // If the number of bytes from the offset to the end of the array is
            // less than the number of bytes you want to copy, you cannot complete
            // the copy.
            if((source.Length - sourceOffset < count) ||
                (target.Length - targetOffset < count))
            {
                throw new ArgumentException("offset to end of array is less than bytes to be copied");
            }

            // The following fixed statement pins the location of the source and
            // target objects in memory so that they will not be moved by garbage
            // collection.
            fixed(byte* pSource = source, pTarget = target)
            {
                // Copy the specified number of bytes from source to target.
                for(int i = 0; i < count; i++)
                {
                    pTarget[targetOffset + i] = pSource[sourceOffset + i];
                }
            }
        }

        // https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/unsafe-code#249-stack-allocation
        private static string IntToString(int value)
        {
            if(value == int.MinValue)
            {
                return "-2147483648";
            }
            int n = value >= 0 ? value : -value;
            unsafe
            {
                char* buffer = stackalloc char[16];
                char* p = buffer + 16;
                do
                {
                    *--p = (char)(n % 10 + '0');
                    n /= 10;
                } while (n != 0);
                if(value < 0)
                {
                    *--p = '-';
                }
                return new string(p, 0, (int)(buffer + 16 - p));
            }
        }

        public long Size { get { return 0x100; } }

        private IValueRegisterField value;

        private enum Registers : long
        {
            Base = 0x0,
            Multiplier = 0x04,
            BitCounter = 0x08,
        }
    }
}
