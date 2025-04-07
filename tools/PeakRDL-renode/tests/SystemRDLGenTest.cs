// Copyright (C) 2024 Antmicro
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

using System;
using System.Reflection;
using System.Collections.Generic;
using System.Linq;
using NUnit.Framework;
using Antmicro.Renode.Core.Structure.Registers;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Utilities;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.IO;
using Mono.Cecil;

namespace Antmicro.Renode.PeripheralsTests
{
    [TestFixture]
    public class SystemRDLGenTest
    {
        private class LoadedAssemblies
        {
            private LoadedAssemblies()
            {
                Assemblies = new Dictionary<string, AssemblyDefinition>();
                compiler = new AdHocCompiler();
            }

            static public LoadedAssemblies Instance
            {
                get
                {
                    if(instance == null)
                    {
                        instance = new LoadedAssemblies();
                    }
                    return instance;
                }
            }

            public IDictionary<string, AssemblyDefinition> Assemblies { get; set; }

            public AssemblyDefinition LoadAssembly(RdlMeta meta)
            {
                var adhocPath = Path.Join(Assembly.GetExecutingAssembly().Location, "../../../../", meta.File);
                if(!Assemblies.TryGetValue(adhocPath, out var assembly))
                {
                    var assemblyPath = compiler.Compile(new[] { adhocPath });
                    assembly = AssemblyDefinition.ReadAssembly(assemblyPath);
                    Assemblies[adhocPath] = assembly;
                    TypeManager.Instance.ScanFile(assemblyPath);
                }
                return assembly;
            }

            private static LoadedAssemblies instance;
            private readonly AdHocCompiler compiler;
        }

        static private IEnumerable<RdlMeta> GetTestCases
        {
            get
            {
                var assembly = Assembly.GetExecutingAssembly();
                if(!assembly.TryFromResourceToTemporaryFile(SystemRDLResource, out var file))
                {
                    Console.WriteLine($"Couldn't load the {SystemRDLResource} resource");
                    yield break;
                }
                var fstream = File.OpenRead(file);

                var options = new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true,
                };
                options.Converters.Add(new TestFieldModeFlagConverter());

                var metas = (List<RdlMeta>)JsonSerializer.Deserialize(fstream, typeof(List<RdlMeta>), options);

                foreach(var meta in metas)
                {
                    yield return meta;
                }
            }
        }

        [OneTimeSetUp]
        public void Setup()
        {
            var peripheralRegisterClasses = typeof(PeripheralRegister).GetTypeInfo().DeclaredNestedTypes.ToDictionary(ti => ti.Name);
            this.ValueRegisterField = peripheralRegisterClasses["ValueRegisterField"];
            Assert.NotNull(this.ValueRegisterField);
            this.FlagRegisterField = peripheralRegisterClasses["FlagRegisterField"];
            Assert.NotNull(this.FlagRegisterField);
            this.RegisterField = peripheralRegisterClasses["RegisterField"];
            Assert.NotNull(this.RegisterField);
        }

        public class TestFieldModeFlagConverter : JsonConverter<FieldMode> {
            public override FieldMode Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
            {
                FieldMode flags = 0;

                if(reader.TokenType != JsonTokenType.StartArray)
                {
                    throw new JsonException("Expected a start of a flag array");
                }

                while(reader.Read())
                {
                    if(reader.TokenType == JsonTokenType.EndArray)
                    {
                        return flags;
                    }

                    var flagStr = reader.GetString();
                    foreach(var flag in Enum.GetValues(typeof(FieldMode)))
                    {
                        if(flagStr == flag.ToString())
                        {
                            flags |= (FieldMode)flag;
                        }
                    }
                }

                throw new JsonException("Unexpected end of stream");
            }

            public override void Write(Utf8JsonWriter writer, FieldMode fieldMode, JsonSerializerOptions options)
            {
                throw new JsonException("Write not supported");
            }
        }

        public class RdlField
        {
            public string Name { get; set; }
            public uint Low { get; set; }
            public uint High { get; set; }
            public FieldMode Mode { get; set; }
            public string FieldType { get; set; }

            public Type GetFieldType() =>
                Type.GetType("Antmicro.Renode.Core.Structure.Registers." + FieldType + ", Infrastructure");
        }

        public class RdlRegister
        {
            public string ClassName { get; set; }
            public string InstanceName { get; set; }
            public ulong Offset { get; set; }
            public ulong ResetValue { get; set; }
            public List<RdlField> Fields { get; set; }
        }

        public class RdlMeta
        {
            public string File { get; set; }
            public string Class { get; set; }
            public string RegisterContainerClass { get; set; }
            public List<RdlRegister> Registers { get; set; }

            public Type GetClass()
            {
                return TypeManager.Instance.GetTypeByName(Class);
            }

            public Type GetRegisterContainerClass() =>
                Type.GetType("Antmicro.Renode.Core.Structure.Registers." + RegisterContainerClass + ", Infrastructure");
        }

        public List<RdlMeta> TestCases { get; set; }

        private void InitPeripheral(RdlMeta meta)
        {
            if(meta.File != "")
            {
                var assembly = LoadedAssemblies.Instance.LoadAssembly(meta);
                Console.WriteLine("Loaded extra peripheral code, assembly: " + assembly.FullName);
            }
            pType = meta.GetClass();
            Assert.IsNotNull(pType);
            peripheral = (IDoubleWordPeripheral)Activator.CreateInstance(pType);
            Assert.IsNotNull(peripheral);
        }

        [Test, TestCaseSource(nameof(GetTestCases))]
        public void TestStaticMeta(RdlMeta meta)
        {
            Console.WriteLine("Checking structure of " + meta.Class + "...");
            InitPeripheral(meta);

            var classes = pType.GetTypeInfo().DeclaredNestedTypes.ToDictionary(ti => ti.Name);
            var cFields = pType.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
                .ToDictionary(fi => fi.Name);

            Assert.AreEqual(meta.Registers.Count, classes.Count);

            var registersCollection = pType.GetProperty("RegistersCollection");
            Assert.NotNull(registersCollection);
            Assert.AreEqual(meta.GetRegisterContainerClass(), registersCollection.PropertyType);

            foreach(var register in meta.Registers)
            {
                Console.WriteLine("- Checking register " + register.InstanceName + "...");


                Assert.IsTrue(classes.ContainsKey(register.ClassName));
                Assert.IsTrue(cFields.ContainsKey(register.InstanceName));

                var rClass = classes[register.ClassName];
                var rInstance = cFields[register.InstanceName];

                Assert.AreEqual(rClass, rInstance.FieldType);

                foreach(var field in register.Fields)
                {
                    Console.WriteLine("  - Checking field " + register.InstanceName + "." + field.Name + "...");
                    var rField = rClass.GetField(field.Name);
                    Assert.IsNotNull(rField);
                    Assert.AreEqual(field.GetFieldType(), rField.FieldType);
                }
            }
        }

        [Test, TestCaseSource(nameof(GetTestCases))]
        public void TestDynamicMeta(RdlMeta meta)
        {
            Console.WriteLine("Checking behavior of " + meta.Class + "...");

            var getPrivateFlags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.GetField;

            InitPeripheral(meta);

            foreach(var register in meta.Registers)
            {
                var regInst = pType.GetField(register.InstanceName, getPrivateFlags).GetValue(peripheral);

                foreach(var field in register.Fields)
                {
                    Console.WriteLine("Testing " + pType.ToString() + "." + register.InstanceName + "." + field.Name + "...");

                    var fieldField = regInst.GetType().GetField(field.Name, getPrivateFlags);
                    Assert.AreEqual(field.GetFieldType(), fieldField.FieldType);

                    var fieldInst = fieldField.GetValue(regInst);

                    var fieldMode = this.RegisterField.GetField("FieldMode").GetValue(fieldInst);
                    var position = this.RegisterField.GetField("Position").GetValue(fieldInst);
                    var width = this.RegisterField.GetField("Width").GetValue(fieldInst);
                    Assert.AreEqual(field.Mode, fieldMode);
                    Assert.AreEqual(field.Low, position);
                    Assert.AreEqual(field.High - field.Low + 1, width);



                    if(fieldInst.GetType() == this.ValueRegisterField)
                    {
                        TestFieldMode((IValueRegisterField)fieldInst, register.Offset, (int)field.Low, field.Mode);
                        TestFieldReset((IValueRegisterField)fieldInst, (int)field.Low, register.ResetValue);
                    }
                    else if(fieldInst.GetType() == this.FlagRegisterField)
                    {
                        TestFieldMode((IFlagRegisterField)fieldInst, register.Offset, (int)field.Low, field.Mode);
                        TestFieldReset((IFlagRegisterField)fieldInst, (int)field.Low, register.ResetValue);
                    }
                    else
                    {
                        Assert.Fail("Unhandled underlying field type: " + fieldInst.GetType());
                    }
                }
            }
        }

        static private IEnumerable<ulong> TestPattern(uint width = sizeof(ulong) * 8)
        {
            yield return 0;
            for(int i = 0; i < width; ++i)
            {
                yield return 1UL << i;
            }
        }

        static private IEnumerable<ulong> TestPatternMask(uint width = sizeof(ulong) * 8)
        {
            ulong l = 0;
            for(int i = 0; i < width; i += 2)
            {
                l |= 1UL << i;
            }
            yield return l;
            yield return l << 1;
        }

        private void TestFieldModeRead(IRegisterField<ulong> field, ulong offset, int low)
        {
            foreach(var pat in TestPattern((uint)field.Width))
            {
                ReportPattern(pat);

                field.Value = pat;
                var read = peripheral.ReadDoubleWord((long)offset);
                Assert.AreEqual(pat, BitHelper.GetMaskedValue(read, low, field.Width) >> low);
                read = peripheral.ReadDoubleWord((long)offset); // Another check to ensure that the value was not modified by the read.
                Assert.AreEqual(pat, BitHelper.GetMaskedValue(read, low, field.Width) >> low);
            }
        }

        private void TestFieldModeRead(IRegisterField<bool> field, ulong offset, int low)
        {
            field.Value = false;
            var read = peripheral.ReadDoubleWord((long)offset);
            Assert.AreEqual(0, BitHelper.GetMaskedValue(read, low, field.Width));
            read = peripheral.ReadDoubleWord((long)offset);
            Assert.AreEqual(0, BitHelper.GetMaskedValue(read, low, field.Width));

            field.Value = true;
            read = peripheral.ReadDoubleWord((long)offset);
            Assert.AreEqual(1, BitHelper.GetMaskedValue(read, low, field.Width) >> low);
            read = peripheral.ReadDoubleWord((long)offset);
            Assert.AreEqual(1, BitHelper.GetMaskedValue(read, low, field.Width) >> low);
        }

        private void TestFieldModeReadToClear(IRegisterField<ulong> field, ulong offset)
        {
            field.Value = BitHelper.GetMaskedValue(~0UL, 0, field.Width) ;
            peripheral.ReadDoubleWord((long)offset);
            Assert.AreEqual(0, field.Value);
        }

        private void TestFieldModeReadToClear(IRegisterField<bool> field, ulong offset)
        {
            field.Value = false;
            peripheral.ReadDoubleWord((long)offset);
            Assert.AreEqual(false, field.Value);

            field.Value = true;
            peripheral.ReadDoubleWord((long)offset);
            Assert.AreEqual(false, field.Value);
        }

        private void TestFieldModeReadToSet(IRegisterField<ulong> field, ulong offset)
        {
            field.Value = 0UL;
            peripheral.ReadDoubleWord((long)offset);
            Assert.AreEqual(~0UL, field.Value);
        }

        private void TestFieldModeReadToSet(IRegisterField<bool> field, ulong offset)
        {
            field.Value = false;
            peripheral.ReadDoubleWord((long)offset);
            Assert.AreEqual(true, field.Value);

            field.Value = true;
            peripheral.ReadDoubleWord((long)offset);
            Assert.AreEqual(true, field.Value);
        }

        private void TestFieldModeWrite(IRegisterField<ulong> field, ulong offset, int low, bool negate = false)
        {
            foreach(var pat in TestPattern((uint)field.Width))
            {
                ReportPattern(pat);

                var v = (negate ? ~(uint)pat : (uint)pat) << low;
                peripheral.WriteDoubleWord((long)offset, v);
                Assert.AreEqual(pat, field.Value);
                peripheral.WriteDoubleWord((long)offset, v);
                Assert.AreEqual(pat, field.Value);
            }
        }

        private void TestFieldModeWrite(IRegisterField<bool> field, ulong offset, int low, bool negate = false)
        {
            field.Value = false;
            peripheral.WriteDoubleWord((long)offset, negate ? (1U << low) : 0U);
            Assert.AreEqual(false, field.Value);

            peripheral.WriteDoubleWord((long)offset, negate ? 0 : (1U << low));
            Assert.AreEqual(true, field.Value);
            peripheral.WriteDoubleWord((long)offset, negate ? 0 : (1U << low));
            Assert.AreEqual(true, field.Value);
        }

        private void TestFieldModeSet(IRegisterField<ulong> field, ulong offset, int low, bool negate = false)
        {
            foreach(var mask in TestPatternMask((uint)field.Width))
            {
                foreach(var pat in TestPattern((uint)field.Width))
                {
                    ReportMaskAndPattern(mask, pat);

                    var v = (negate ? ~(uint)pat : (uint)pat) << low;
                    field.Value = mask;
                    peripheral.WriteDoubleWord((long)offset, v);
                    Assert.AreEqual(mask | pat, field.Value);
                    peripheral.WriteDoubleWord((long)offset, v);
                    Assert.AreEqual(mask | pat, field.Value);
                    peripheral.WriteDoubleWord((long)offset, 0U);
                    Assert.AreEqual(mask | pat, field.Value);
                }
            }
        }

        private void TestFieldModeSet(IRegisterField<bool> field, ulong offset, int low, bool negate = false)
        {
            field.Value = false;
            peripheral.WriteDoubleWord((long)offset, negate ? (1U << low) : 0U);
            Assert.AreEqual(false, field.Value);

            peripheral.WriteDoubleWord((long)offset, negate ? 0 : (1U << low));
            Assert.AreEqual(true, field.Value);
            peripheral.WriteDoubleWord((long)offset, negate ? 0 : (1U << low));
            Assert.AreEqual(true, field.Value);
            peripheral.WriteDoubleWord((long)offset, negate ? (1U << low) : 0);
            Assert.AreEqual(true, field.Value);
        }

        private void TestFieldModeToggle(IRegisterField<ulong> field, ulong offset, int low, bool negate = false)
        {
            foreach(var mask in TestPatternMask((uint)field.Width))
            {
                field.Value = mask;
                foreach(var pat in TestPattern((uint)field.Width))
                {
                    ReportMaskAndPattern(mask, pat);

                    var v = (negate ? ~(uint)pat : (uint)pat) << low;
                    peripheral.WriteDoubleWord((long)offset, v);
                    Assert.AreEqual((mask | pat) & ~(mask & pat), field.Value);
                    peripheral.WriteDoubleWord((long)offset, v);
                    Assert.AreEqual(mask, field.Value);
                }
            }
        }

        private void TestFieldModeToggle(IRegisterField<bool> field, ulong offset, int low, bool negate = false)
        {
            field.Value = false;
            peripheral.WriteDoubleWord((long)offset, negate ? (1U << low) : 0U);
            Assert.AreEqual(false, field.Value);

            peripheral.WriteDoubleWord((long)offset, negate ? 0 : (1U << low));
            Assert.AreEqual(true, field.Value);
            peripheral.WriteDoubleWord((long)offset, negate ? (1U << low) : 0U);
            Assert.AreEqual(true, field.Value);

            peripheral.WriteDoubleWord((long)offset, negate ? 0 : (1U << low));
            Assert.AreEqual(false, field.Value);
        }

        private void TestFieldModeWriteOneToClear(IRegisterField<ulong> field, ulong offset, int low, bool negate = false)
        {
            foreach(var mask in TestPatternMask((uint)field.Width))
            {
                foreach(var pat in TestPattern((uint)field.Width))
                {
                    ReportMaskAndPattern(mask, pat);

                    var v = (negate ? ~(uint)pat : (uint)pat) << low;
                    field.Value = mask;
                    peripheral.WriteDoubleWord((long)offset, v);
                    Assert.AreEqual(mask & ~pat, field.Value);
                }

            }
        }

        private void TestFieldModeWriteOneToClear(IRegisterField<bool> field, ulong offset, int low, bool negate = false)
        {
            field.Value = true;
            peripheral.WriteDoubleWord((long)offset, negate ? (1U << low) : 0U);
            Assert.AreEqual(true, field.Value);

            peripheral.WriteDoubleWord((long)offset, negate ? 0U : (1U << low));
            Assert.AreEqual(false, field.Value);

            peripheral.WriteDoubleWord((long)offset, negate ? 0U : (1U << low));
            Assert.AreEqual(false, field.Value);
        }

        private static void ReportPattern(ulong pat)
        {
            Console.WriteLine("  - Test pattern: " + FormatBits(pat));
        }

        private static void ReportMaskAndPattern(ulong mask, ulong pat)
        {
            Console.WriteLine("  - Test Mask:    " + FormatBits(mask));
            Console.WriteLine("    Test pattern: " + FormatBits(pat));
        }

        private void TestFieldMode(IRegisterField<ulong> field, ulong offset, int low, FieldMode mode)
        {
            if(FieldModeHelper.ReadBits(mode) != 0)
            {
                Console.WriteLine("  Performing read test...");
            }
            switch(FieldModeHelper.ReadBits(mode))
            {
                case FieldMode.Read: TestFieldModeRead(field, offset, low); break;
                case FieldMode.ReadToClear: TestFieldModeReadToClear(field, offset); break;
                case FieldMode.ReadToSet: TestFieldModeReadToSet(field, offset); break;
            }

            if(FieldModeHelper.WriteBits(mode) != 0)
            {
                Console.WriteLine("  Performing write test...");
            }
            switch(FieldModeHelper.WriteBits(mode))
            {
                case FieldMode.Write: TestFieldModeWrite(field, offset, low); break;
                case FieldMode.Set: TestFieldModeSet(field, offset, low); break;
                case FieldMode.Toggle: TestFieldModeToggle(field, offset, low); break;
                case FieldMode.WriteOneToClear: TestFieldModeWriteOneToClear(field, offset, low); break;
                case FieldMode.WriteZeroToClear: TestFieldModeWriteOneToClear(field, offset, low, negate: true); break;
                case FieldMode.WriteZeroToSet: TestFieldModeSet(field, offset, low, negate: true); break;
                case FieldMode.WriteZeroToToggle: TestFieldModeToggle(field, offset, low, negate: true); break;
            }
        }

        private void TestFieldMode(IRegisterField<bool> field, ulong offset, int low, FieldMode mode)
        {
            if(FieldModeHelper.ReadBits(mode) != 0)
            {
                Console.WriteLine("  Performing read test...");
            }
            switch(FieldModeHelper.ReadBits(mode))
            {
                case FieldMode.Read: TestFieldModeRead(field, offset, low); break;
                case FieldMode.ReadToClear: TestFieldModeReadToClear(field, offset); break;
                case FieldMode.ReadToSet: TestFieldModeReadToSet(field, offset); break;
            }

            if(FieldModeHelper.WriteBits(mode) != 0)
            {
                Console.WriteLine("  Performing write test...");
            }
            switch(FieldModeHelper.WriteBits(mode))
            {
                case FieldMode.Write: TestFieldModeWrite(field, offset, low); break;
                case FieldMode.Set: TestFieldModeSet(field, offset, low); break;
                case FieldMode.Toggle: TestFieldModeToggle(field, offset, low); break;
                case FieldMode.WriteOneToClear: TestFieldModeWriteOneToClear(field, offset, low); break;
                case FieldMode.WriteZeroToClear: TestFieldModeWriteOneToClear(field, offset, low, negate: true); break;
                case FieldMode.WriteZeroToSet: TestFieldModeSet(field, offset, low, negate: true); break;
                case FieldMode.WriteZeroToToggle: TestFieldModeToggle(field, offset, low, negate: true); break;
            }
        }

        void TestFieldReset(IRegisterField<ulong> field, int low, ulong registerResetValue)
        {
            var expect = registerResetValue >> low;
            field.Value = BitHelper.GetMaskedValue(~expect, 0, field.Width);

            var registers = (peripheral as IProvidesRegisterCollection<DoubleWordRegisterCollection>).RegistersCollection;
            registers.Reset();

            Assert.AreEqual(field.Value, expect);
        }

        void TestFieldReset(IRegisterField<bool> field, int low, ulong registerResetValue)
        {
            var expect = BitHelper.GetMaskedValue(registerResetValue >> low, 0, 1) == 1;
            field.Value = !expect;

            var registers = (peripheral as IProvidesRegisterCollection<DoubleWordRegisterCollection>).RegistersCollection;
            registers.Reset();

            Assert.AreEqual(field.Value, expect);
        }

        // Older .NET versions do not support "b" format specifier
        static string FormatBits(ulong value)
        {
            string res = "";
            foreach(var bit in BitHelper.GetBits(value).Reverse())
            {
                res += bit ? '1' : '0';
            }
            return res;
        }

        private IDoubleWordPeripheral peripheral;
        private Type pType;

        private Type ValueRegisterField;
        private Type FlagRegisterField;
        private Type RegisterField;

        private const string SystemRDLResource = "Antmicro.Renode.PeripheralsTests.SystemRDLJson";
    }
}