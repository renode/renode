# PeakRDL-Renode

Copyright (c) 2024 [Antmicro](https://antmicro.com)

Renode interface exporter plugin for PeakRDL.

## Usage

### Prerequisites

This project requires Python 3.11 or newer and [PeakRDL package](https://pypi.org/project/peakrdl/):

```
python3 -m pip install peakrdl
```

### Installing the exporter

Execute the following from `PeakRDL-renode` directory:

```
python3 -m pip install .
```

### Using the exporter

Generation of the partial C# class is done by calling the renode plugin to the peakrdl package:

```bash
peakrdl renode [-h] [-I INCDIR] [-D MACRO[=VALUE]] [-t TOP] [--rename INST_NAME] [-P PARAMETER=VALUE] [--remap-state STATE] -o OUTPUT -N NAMESPACE [-n NAME] [-f FILE] [--peakrdl-cfg CFG] FILE [FILE ...]
```

* `FILE` - SystemRDL file to read
* `-n/--name ` - name of the peripheral class to be exported
* `-N/--namespace` - namespace in which this class should reside. Relative to
  `Antmicro.Renode.Peripherals`, for example `-N Mocks` will resolve to
  `Antmicro.Renode.Peripherals.Mocks`
* `-o OUTPUT` - path/name of the file to export the C# code into

For example:

```
peakrdl renode -n MyI2CController -N I2C -o MyI2CController_gen.cs i2c_regs.rdl
```

will generate _MyI2CController_gen.cs_ file containing `MyI2CController` partial class in
`Antmicro.Renode.Peripherals.I2C` namespace.

### Working with the generated code

The generated C# code contains a
[partial class](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/partial-classes-and-methods)
that serves as a starting point for writing your peripheral model. Do not edit the generated file.
Instead write the rest of the implementation in another file, within the same .NET/Mono assembly.

Since there's some initialization code within the generated part, there are a couple small differences in
how some things are handled in this approach, compared to the examples shown in the
[Peripheral Modeling Guide](https://renode.readthedocs.io/en/latest/advanced/writing-peripherals.html).

#### Peripheral initialization

First of all, the constructor is defined in the generated code. Use `void Init()` partial method instead
- it gets called after the generated fields get initialized.

Define an `Init` method and initialize your class fields and properties inside it, for example:

```csharp
public partial class MyPeripheral
{
    List<int> myList; // An example field that needs to be initialized

    partial void Init()
    {
        myList = new List<int>;
    }

    // ... The rest of your code goes here
}
```

#### Accessing registers and fields defined in SystemRDL

Registers are available as fields that are instances of classes generated for each `register` entry
in SystemRDL. Those classes contain fields that correspond to `field` entries in your SystemRDL file.

For example, if your SystemRDL file contains a `register` named `status`, with a field called
`busy`, like that:

```systemrdl
register {
  name = "status";
  regwidth = 32;
  field {
    name = "busy";
    sw = "rw";
    hw = "rw";
  } busy [0:0];
  // ... more fields 
} status @ 0x4;
```

You can access it like that:

```csharp
public partial class MyPeripheral
{
    public void AccessBusy()
    {
        // Read the register field
        bool isBusy = this.Status.BUSY.Value
        // Write to the register's field
        this.Status.BUSY.Value = false;
    }
}
```

Fields which width is equal to one are represented by a type that implements `IFlagRegisterField`
interface, wider fields are represented by a type that implements `IValueRegisterField` interface.

The register name is always converted to _CamelCase_, while the field name is converted to
_UPPPER_CASE_.

#### Binding callbacks to field access

Normally, the callbacks are attached to the register when its defined. However in our case
the registers are already defined, so adding read/write callbacks has to be done manually after
the fields and registers get instantiated.
Starting from [4e23f6c](https://github.com/renode/renode/commit/4e23f6c7bcf3b7bd68d28b429001b6b06727db2a)
Renode exposes the callbacks as properties of register fields so you can add your logic like in the
example below:

```csharp
// Read the flag negated
this.Status.BUSY.ValueProviderCallback += (value) => !value;
```

#### Memory

PeakRDL-renode generates special structures and logic for accessing memories defined using `mem`
nodes. Currently only memories that contain one register (array) are supported.

For each memory a wrapper structure is generated. It defines read/write access methods for the
software and an indexer method for implementation of the hardware, for example, for the included
SystemRDL example `tests/models/rdl/mem1.rdl` we get:

```csharp
protected class Mem1_StructureContainer
{
    public Mem1_StructureWrapper this[long index] {
        get
        {
            // ...
        }
    }

    public uint ReadDoubleWord(long offset)
    {
        // ...
    }

    public void WriteDoubleWord(long offset, uint value)
    {
        // ...
    }

    // .. More implementation below
}
```

This structure is instantiated within the peripheral as a member named after the memory instance:
```csharp
/// <summary> Memory "mem1" at 0x10 </summary>
protected Mem1_StructureContainer Mem1;
```

The type of an object returned by the indexer method is another wrapper type. It provides access
to the underlying memory at a given entry index and exposes the entry's fields as
properties that map to the memory.

An example usage is shown below:
```csharp
public partial class MyPeripheral
{
    Mem1_StructureContainer Mem1;

    // ...

    public void AccessMemory()
    {
        // Read the flag2 field of the first entry
        bool flag2 = Mem1[0].FLAG2;
        // Write to the VALUE1 field of the third entry
        Mem1[2].VALUE1 = 5;
    }
}
```

The types of the properties are assigned depending on the field width:
* `width == 1` => `bool`
* `1 < width <= 8` => `byte`
* `8 < width <= 16` => `ushort`
* `16 < width <= 32` => `uint`
* `32 < width <= 64` => `ulong`

Fields wider than 64 bits are not supported.

### Software read/write operations

All of the peripheral's registers and memories are assumed to be described by the SystemRDL code.
The read and write methods are fully generated, for example:
```csharp
uint IDoubleWordPeripheral.ReadDoubleWord(long offset)
{
    if(offset >= 16 && offset < 16L + Mem1.Size)
    {
        return Mem1.ReadDoubleWord(offset - 16);
    }
    return RegistersCollection.Read(offset);
}

void IDoubleWordPeripheral.WriteDoubleWord(long offset, uint value)
{
    if(offset >= 16 && offset < 16L + Mem1.Size)
    {
        Mem1.WriteDoubleWord(offset - 16, value);
        return;
    }
    RegistersCollection.Write(offset, value);
}
```
