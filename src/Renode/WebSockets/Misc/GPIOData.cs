//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Miscellaneous;

namespace Antmicro.Renode.WebSockets.Misc
{
    internal static class GPIOData
    {
        public static WebSocketAPIResponse ButtonSet(IMachine _, IPeripheral peripheral, bool value)
        {
            var button = peripheral as Button;

            if(value && button.Pressed)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("trying to press button which is already pressed");
            }
            else if(!value && !button.Pressed)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse("trying to release button which is not pressed");
            }

            if(value)
            {
                button.Press();
            }
            else
            {
                button.Release();
            }

            return WebSocketAPIUtils.CreateActionResponse("ok");
        }
    }
}
