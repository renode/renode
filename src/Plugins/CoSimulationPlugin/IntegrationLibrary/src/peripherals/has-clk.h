//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#ifndef HasCLk_H
#define HasCLk_H

class HasCLk
{
public:
    virtual void clkHigh() = 0;
    virtual void clkLow() = 0;
};

#endif
