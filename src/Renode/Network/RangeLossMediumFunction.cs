//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals.Wireless;

namespace Antmicro.Renode.Network
{
    public static class RangeLossMediumExtension
    {
        public static void SetRangeLossWirelessFunction(this WirelessMedium wirelessMedium, int lossRange = 0, float txRatio = 0, float rxRatio = 0)
        {
            var function = new RangeLossMediumFunction();
            function.LossRange = lossRange;
            function.TxRatio = txRatio;
            function.RxRatio = rxRatio;
            wirelessMedium.SetMediumFunction(function);
        }
    }

    public class RangeLossMediumFunction : IMediumFunction
    {
        public bool CanReach(Position from, Position to)
        {
            var distance = Math.Sqrt(Math.Pow((double)(to.X - from.X), 2) + Math.Pow((double)(to.Y - from.Y), 2) + Math.Pow((double)(to.Z - from.Z), 2));
            var receptionSuccessRatio = 1 - ((distance / LossRange) * (1 - RxRatio));
            var receptionSuccess = EmulationManager.Instance.CurrentEmulation.RandomGenerator.NextDouble();

            if(receptionSuccess > receptionSuccessRatio)
            {
                return false;
            }
            return true;
        }

        public bool CanTransmit(Position from)
        {
            var transmissionSuccess = EmulationManager.Instance.CurrentEmulation.RandomGenerator.NextDouble();
            if(transmissionSuccess > TxRatio)
            {
                return false;
            }
            return true;
        }

        public int LossRange { get; set; }

        public float TxRatio
        {
            get
            {
                return txRatio;
            }

            set
            {
                if(value < 0 || value > 1.0f)
                {
                    throw new RecoverableException("TxRatio must be between 0 and 1.");
                }
                else
                {
                    txRatio = value;
                }
            }
        }

        public float RxRatio
        {
            get
            {
                return rxRatio;
            }

            set
            {
                if(value < 0 || value > 1.0f)
                {
                    throw new RecoverableException("RxRatio must be between 0 and 1.");
                }
                else
                {
                    rxRatio = value;
                }
            }
        }

        public string FunctionName { get { return Name; } }

        private float txRatio;
        private float rxRatio;
        private const string Name = "range_loss_medium_function";
    }
}