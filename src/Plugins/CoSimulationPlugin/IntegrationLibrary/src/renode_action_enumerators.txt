//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

// This file contains enumerators of the action type used by the Renode protocol.
// The mentioned protocol is used to communicate with HDL simulators.
// The values below must be in sync with ActionType from Renode (defined in C#).
// The content on this file must be compatible with the enum syntax in both C++ and SystemVerilog.
// Append new actions to the end to preserve compatibility.
invalidAction = 0,
tickClock = 1,
writeRequest = 2,
readRequest = 3,
resetPeripheral = 4,
logMessage = 5,
interrupt = 6,
disconnect = 7,
error = 8,
ok = 9,
handshake = 10,
pushDoubleWord = 11,
getDoubleWord = 12,
pushWord = 13,
getWord = 14,
pushByte = 15,
getByte = 16,
isHalted = 17,
registerGet = 18,
registerSet = 19,
singleStepMode = 20,
readRequestByte = 21,
readRequestWord = 22,
readRequestDoubleWord = 23,
readRequestQuadWord = 24,
writeRequestByte = 25,
writeRequestWord = 26,
writeRequestDoubleWord = 27,
writeRequestQuadWord = 28,
pushQuadWord = 29,
getQuadWord = 30,
pushConfirmation = 31,
step = 100
