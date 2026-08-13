//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

namespace Antmicro.Renode.Network.ExternalControl
{
    // Needs to be in sync with `command_type_t` in C
    public enum CommandType : byte
    {
        Request = 0x0,
        EventRequest = 0x1,
        Success = 0x2,
        InvalidCommand = 0x3,
        Error = 0x4,
    }

    public static class CommandTypeExtension
    {
        public static bool IsRequest(this CommandType type)
        {
            return type == CommandType.Request || type == CommandType.EventRequest;
        }
    }
}
