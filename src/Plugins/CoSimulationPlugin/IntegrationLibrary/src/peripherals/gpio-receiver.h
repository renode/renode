//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#ifndef GpioReceiver_H
#define GpioReceiver_H

class GPIOReceiver
{
public:
    virtual void onGPIO(int number, bool value) = 0;
};

#endif
