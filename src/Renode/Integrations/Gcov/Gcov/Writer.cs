//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.IO;

using Antmicro.Renode.Utilities;

namespace Antmicro.Renode.Integrations.Gcov
{
    public class Writer : BinaryWriter
    {
        public static int SizeOf(string value)
        {
            return (int)Math.Ceiling(((double)value.Length + 1) / 4);
        }

        public Writer(Stream stream) : base(stream)
        {
        }

        public override void Write(byte[] value)
        {
            if(BitConverter.IsLittleEndian)
            {
                for(var i = value.Length - 1; i >=0; i--)
                {
                    base.Write(value[i]);
                }
            }
            else
            {
                base.Write(value);
            }
        }

        public override void Write(int value)
        {
            if(!BitConverter.IsLittleEndian)
            {
                value = (int)Misc.SwapBytesUInt((uint)value);
            }

            base.Write(value);
        }

        public override void Write(ulong value)
        {
            if(!BitConverter.IsLittleEndian)
            {
                value = Misc.SwapBytesULong(value);
            }

            base.Write(value);
        }

        public override void Write(string value)
        {
            var length = SizeOf(value);

            Write(length);
            for(var i = 0; i < value.Length; i++)
            {
                base.Write(value[i]);
            }

            var padding = (4 - (value.Length % 4));
            for(var i = 0; i < padding; i++)
            {
                this.Write((byte)0);
            }
        }
    }
}
