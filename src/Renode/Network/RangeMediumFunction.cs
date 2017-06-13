//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using Emul8.Peripherals.Wireless;

namespace Antmicro.Renode.Network
{
    public static class RangeMediumExtension
    {
        public static void SetRangeWirelessFunction(this WirelessMedium wirelesMedium, int range = 0)
        {
            var function = new RangeMediumFunction();
            function.Range = range;
            wirelesMedium.SetMediumFunction(function);
        }
    }

    public sealed class RangeMediumFunction : IMediumFunction
    {
        public bool CanReach(Position from, Position to)
        {
            // any transmission that is not within range will fail
            if(Math.Sqrt(Math.Pow((double)(to.X - from.X), 2) + Math.Pow((double)(to.Y - from.Y), 2) + Math.Pow((double)(to.Z - from.Z), 2)) > Range)
            {
                return false;
            }
            return true;
        }

        public bool CanTransmit(Position from)
        {
            return true;
        }

        public int Range { get; set; }

        public string FunctionName { get { return Name; } }

        private const string Name = "range_medium_function";
    }
}

