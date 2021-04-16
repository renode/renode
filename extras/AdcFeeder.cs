//
// Copyright (c) 2010-2021 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
// 

using System;
using Antmicro.Renode.Peripherals.Analog;

namespace Externals
{
    public static class AdcFeeder
    {
        public static void FeedChannel(this STM32F0_ADC adc, int channel, int numberOfSamples)
        {
            for(var i = 0; i < numberOfSamples; i++)
            {
                var value = GenerateSample(i);
                adc.FeedVoltageSampleToChannel(channel, value, 1);
            }
        }

        private static decimal GenerateSample(int sampleNumber)
        {
            // here goes the logic of generating samples
            return 0;
        }
    }
}
