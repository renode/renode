Platform description format
===========================

Indentation
-----------
Within our format the meaningful indentation (similar to e.g. Python) is used *along* with braces ({, }).
The rules are as follows:

1. Only spaces are used for indentation and indent has to be a multiple of four spaces.
2. Syntactically one level of indentation corresponds to one brace (opening one if we indent, and closing if dedent).
3. The indentation inside braces is not meaningful, this also applies to new line characters.
   They are all treated as white characters.
   Having a meaningful indentation is also called being in an indent mode (as opposed to non-indent mode).
   For separation of elements (that are lines in indent mode) a semicolon must be used.

For example these files are equivalent:

.. code-block:: none

    line1
    line2
        line3
        line4
            line5
        line6

.. code-block:: none
    line1
    line2 { line3; line4 { line5 }; line 6 }
        

Comments
--------
There are two types of comments:

- line comments that start with ``//`` and continue to the end of the line;
- multiline comments, delimited by ``/*`` and ``*/`` and can span multiple lines.

Both comments can be used in the indent and non-indent mode, but there is one special rule.
When a multiline comment spans multiple lines, it has to end on the end of the line.
It is done this way, because otherwise it would be hard to tell what indenation should be used for the rest of the line.

In other words this source is legal:

.. code-block:: none

    line1 /* here a comment starts
     here it continues
    and here ends*/
    line2

But this one is not:

.. code-block:: none

    line1 /* here a comment starts
     here it continues
    and here ends*/ line2

Basic structure
---------------
Each platform description format consists of *entries*.
Entry is a fundamental unit of peripheral description.
The basic format of an entry is as follows:

.. code-block:: none

    variableName: TypeName registrationInfo
        attribute1
        attribute2
        ...
        attributeN

All of ``TypeName``, ``registrationInfo`` and ``attributes`` are optional, but at least one of them must be present.
If an entry contains a TypeName, then it is a *creating entry* (otherwise it is an *updating entry*).
Each creating entry declares a variable, there can be only one declaration for given variable and it must be the first entry that is encountered during parse of the file unless the variable is declared before parsing.
For example all peripherals that are registered in the machine are also imported as variables and can have their updating entries (but not creating one).
In other words this code is legal:

.. code-block:: none

    variable1: SomeType
        property: value

    variable1:
        property: otherValue

But this one results in an error:

.. code-block:: none

    variable1:
        property: value

    variable1: SomeType
        property: otherValue

The consecutive entries (for the given variable) are called updating because they can update some informations provided by the former ones.
Eventually all entries corresponding to the given variable are *merged* so that the merge result contains attributes from all entries, possibly some invalidated by some other.

TypeName must be provided with the full namespace the type is located in.
However, if the namespace starts with ``Emul8.Peripherals``, then this part can be omitted.

A creating entry can have an optional prefix ``local``, then variable declared in this entry is called a *local* variable.
The prefix is only used with creating entry, not with updating one.
For example:

.. code-block:: none

    local cpu: SomeCPU
        StringProp: "a"
    
    cpu:
        IntProp: 32

If the variable is local, then we can reference it only within that file.
This will be clearer after reading the next part, but generally if one file depends on another, both can declare same named local variable and they are completely independent, in particular they can have different types.

Depending on other files
------------------------
One description can depend on another, then it can use all (non-local) variables from that file.
Note that also all non-local variables from file we're depending on cannot have creating entries.
In other words, depending on another file is like having it pasted at the top of the file with the exception of local variables.

The ``using`` keyword is used to declare dependency:

.. code-block:: none

    using "path"

The line above is called a *using entry*.
Using entries can only be a top part of the file, so all using entries has to come before entries.
There is also a syntax that lets user depend on a file but prepend all variables within that file with a prefix:

.. code-block:: none

    using "path" prefixed "prefix"

Then ``prefix`` is applied to each variable of the file ``path``.

Since files mentioned in path can further depend on other files, this can sometimes lead to a cycle.
This is detected by the format interpreter and an error with informations about the cycle is issued.

Values
------
*Value* is a notion widely used in the platform description format.
There are three kinds of values:

- *simple values* that can be further divided into:

  * strings (delimited by a double quote with ``\"`` used as an escaped double quote);
  * boolean values (either ``true`` or ``false``);
  * numbers (decimal or hexadecimal with the ``0x`` prefix);
  * ranges (described below)
- reference values, which points to a variable and are given just as the name of the variable;
- inline objects that denote an object described in value itself and not tied to any variable (described later).

A range represents an interval and can be given in two forms:

- ``<begin, end>`` or
- ``<begin, +size>`` where ``begin``, ``end`` and ``size`` are decimal or hexadecimal numbers.

Examples: ``<0, 100>``, ``<0x10000, +0x200>``.

Registration info
-----------------
Registration info tells in which register a given peripheral should be registered and how.
A peripheral can be registered in one or more registers.
For single registration the format of a registration info is as follows:

.. code-block:: none

    @ register registrationPoint as "alias"

where ``registrationPoint`` is a value and is optional.
The ``as "alias"`` part is called an *alias* and is also optional.
Using ``registrationPoint`` the registration point is created or directly used (if the value specified is a registration point):
If the registration point is not given, then either ``NullRegistrationPoint`` is used or (if ``NullRegistrationPoint`` is not accepted) a registration point with no constructor parameters or all parameters optional.
If the registration point is a simple value, then a registration point with a constructor taking one parameter to which this simple value can be converted and possible other parameters optional is used.
Note that any ambiguity in two cases mentioned above will lead to an error.
If the registration point is a reference value or an inline object then they are directly used as a registration point.

During registration, the registered peripheral is normally given the same name as was the name of the variable.
User can, however, override this name with a different one using mentioned alias.
Then the name given in the alias is used.

Multiple registration is also supported and has the following form:

.. code-block:: none

    @ {
        register1 registrationPoint1;
        register2 registrationPoint2;
        ...
        registerN registrationPointN
    } as "alias"

Meaning and optionality of the elements is the same as it was in the previous case with the only difference that the peripheral is registered multiple times, possibly in different registers.
Note that - as was mentioned at the beginning of this document - the indentation within braces does not matter.

Registration info can be given in any entry (creating or updating), also in more than one entry.
In such case only the registration from the newest entry takes place.
Registration can also be cancelled, i.e. overridden without giving new registration info.
This is done using ``@ none`` notation, for example:

.. code-block:: none

    variable: @none

Attributes
----------
There are three kinds of attributes:

- constructor or property attributes;
- interrupt attributes;
- init attributes.

Constructor or property attributes
++++++++++++++++++++++++++++++++++
The constructor or property attribute has the following form:

.. code-block:: none

    name: value

``name`` is the name of the property (if the initial letter is uppercase) or constructor parameter (otherwise) and ``value`` is a value.
When used with property, if attribute's value is convertible to this property type, then such converted value will be set (otherwise an error is issued).
Note, however, that another entry may update the property so that only the final (i.e. the last containing an attribute setting this property) entry is effective.
Keyword ``none`` can also be used instead of a value.
Having it there means that the property is not set using any value and its value *before applying the description* is kept.
It can be useful when some entry sets some value and we want to update this entry but not set any value.

Constructor attributes are merged in a similar way, i.e. attributes from all entries belonging to the given variable are analyzed and for each name we take the last one having such name.
The constructor of the peripheral is chosen based on the set of merged attributes.
For each possible constructor of the type specified in the creating entry we check whether:

- each parameter of the constructor has default value or corresponding attribute, i.e. attribute having same name as the name of the parameter;
- corresponding attribute has value convertible (if simple type) or assignable (otherwise) to the parameter type;
- all attributes have been used.

If all the conditions are satisfied then the analyzed constructor is marked as usable.
If only one constructor is usable, then the object is created using this constructor.
If there is no such constructor or there are more than one, an error is issued.

Because it is much easier to debug constructor selection problems if all the data are in one place (i.e. name of the type and constructor attributes), a warning is issued whenever non creating entry contains construcor parameters (effectively updating a creating one).

Note that it is only possible to provide constructor attributes for entry whose variable is going to be created, so it is not possible to provide any on variables represeting peripheral existing before processing of the description.

Interrupt attributes
++++++++++++++++++++
As the name suggests, interrupt attributes are used to specify which *our* (i.e. on variable in which the attribute can be find) interrupts are connected and where.
The simplest format of such attribute is as follows:

.. code-block:: none

    -> destination@number

where ``destination`` is a variable implementing ``IGPIOReceiver`` interface and ``number`` is the destination interrupt number.
Note that there is nothing specified on the left side - this is only possible if there is a single property of type ``GPIO`` and this is the one that gets connected.
Whenever user wants (or has) to specify which property should be connected, a more general form can be used:

.. code-block:: none

    propertyName -> destination@number

where ``propertyName`` is the name of the property (of the ``GPIO`` type) that should be connected.
Also, if the type implements ``INumberedGPIOOutput``, a number can be used instead of the property name.

If more than one interrupt is to be connected to the same destination peripheral, the following form of atribute can be used:

.. code-block:: none

    [irq1, irq2, ..., irqN] -> destination@[irqDest1, irqDest2, ..., irqDestN]

Where ``irq1`` connects to ``irqDest1`` etc.
Again, ``irq``s can be names or numbers (if ``INumberedGPIOOutput`` is implemented) and ``irqDest``s has to be numbers.
Naturally, arity of sources and destinations has to match.

There is also a notation used in case of local interrupts:

.. code-block:: none

    source -> destination#index@interrupt

``destination`` has to implement ``ILocalGPIOReceiver`` and index is the index of the local GPIO receiver.
This notation can also be used with multiple interupts:

.. code-block:: none

    [irq1, irq2, ..., irqN] -> destination#index@[irqDest1, irqDest2, ..., irqDestN]

Just as in the case of properties, interrupt attributes can update older ones.
This is done basing on source interrupt, i.e. if two attributes from different entries use the same source interrupt, only the one from the latter is used.
Again, as in properties, user may want to cancel irq connection without specifying a different one.
The keyword ``none`` can be used for this purpose:

.. code-block:: none

    source -> none

Init attributes
+++++++++++++++
Init attributes are used to execute monitor commands on the variable.
They have one of the following forms:

.. code-block:: none

    init:
        monitorStatement1
        monitorStatement2
        ...
        monitorStatementN

.. code-block:: none

    init add:
        monitorStatement1
        monitorStatement2
        ...
        monitorStatementN

The difference between them is that during merge phase the first one overrides given variable's previous init attribute (if there is one) and the second one concanates itself to that previous one.
Final entry is eventually executed: every statement is prepended with the name of the peripheral the variable is tied to and then directly parsed by monitor.
Note that it means that the init section is only legal for variables that are registered.

Inline objects
--------------
Inline objects are values similar to reference values, but instead of creating a separate variable and then referencing it, it is defined directly in the place of reference.
The form is as follows:

.. code-block:: none

    new Type
        attribute1
        attribute2
        ...
        attributeN

Effect is the same as creating an entry of this type and with those attributes, but it cannot be updated and is only available in the place of reference.
So, for example, these codes lead to the same effect:

.. code-block:: none

    variable: SomeType
        SomeProperty: point
    
    point: Point
        x: 5
        y: 3

.. code-block:: none

    variable: SomeType
        SomeProperty: new Point {x: 5; y: 3}
