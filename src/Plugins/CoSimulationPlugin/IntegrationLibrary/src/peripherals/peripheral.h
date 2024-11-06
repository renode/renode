//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#ifndef Peripheral_H
#define Peripheral_H

class Peripheral
{
public:
    virtual void evaluateModel() = 0;
    virtual void reset() = 0;
};

#endif
