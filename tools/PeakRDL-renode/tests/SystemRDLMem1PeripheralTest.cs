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
using NUnit.Framework;
using Antmicro.Renode.Peripherals.Bus;
using System.Collections.Generic;


namespace Antmicro.Renode.PeripheralsTests
{
    [TestFixture]
    public class SystemRDLMem1PeripheralTest
    {
        public struct TestCase {
            public bool FLAG1 { get; set; }
            public bool FLAG2 { get; set; }
            public byte VALUE1 { get; set; }
            public uint VALUE2 { get; set; }
            public uint Memory { get; set; }
        }

        static public List<TestCase> testCases = new List<TestCase> {
            new TestCase {
                FLAG1 = false,
                FLAG2 = false,
                VALUE1 = 0x0,
                VALUE2 = 0x0,
                Memory = 0x0000_0000,
            },
            new TestCase {
                FLAG1 = true,
                FLAG2 = false,
                VALUE1 = 0x0,
                VALUE2 = 0x400,
                Memory = 0x0001_0001,
            },
            new TestCase {
                FLAG1 = true,
                FLAG2 = true,
                VALUE1 = 0xf,
                VALUE2 = 0x216400,
                Memory = 0x0859_003f,
            },
            new TestCase {
                FLAG1 = true,
                FLAG2 = true,
                VALUE1 = 0xf,
                VALUE2 = 0x859,
                Memory = 0x0002_167f,
            },
            new TestCase {
                FLAG1 = false,
                FLAG2 = true,
                VALUE1 = 0xf,
                VALUE2 = 0x1ff_ffff,
                Memory = 0xffff_fffe,
            },
        };

        [OneTimeSetUp]
        public void Setup()
        {
            peripheral = new Peripherals.Mocks.Mem1Peripheral();
        }

        [Test]
        public void TestSize()
        {
            Assert.AreEqual(16, peripheral.Mem1.Size);
        }

        [Test]
        public void TestBounds()
        {
            var _ = peripheral.Mem1[mem1ElementCount - 1];
            try
            {
                _ = peripheral.Mem1[mem1ElementCount];
            }
            catch(IndexOutOfRangeException)
            {
                return;
            }
            Assert.Fail("Out-of-bounds memory access succeeded");
        }

        [Test, TestCaseSource(nameof(testCases))]
        public void TestRead(TestCase testCase)
        {
            for(long i = 0; i < peripheral.Mem1.Size / 4; ++i)
            {
                (peripheral as IDoubleWordPeripheral)
                    .WriteDoubleWord(mem1Offset + i * 4, testCase.Memory);
            }

            for(long i = 0; i < peripheral.Mem1.Size / mem1ElementCount; ++i)
            {
                Assert.AreEqual(testCase.FLAG1, peripheral.Mem1[i].FLAG1);
                Assert.AreEqual(testCase.FLAG2, peripheral.Mem1[i].FLAG2);
                Assert.AreEqual(testCase.VALUE1, peripheral.Mem1[i].VALUE1);
                Assert.AreEqual(testCase.VALUE2, peripheral.Mem1[i].VALUE2);
            }
        }

        [Test, TestCaseSource(nameof(testCases))]
        public void TestWrite(TestCase testCase)
        {
            for(long i = 0; i < peripheral.Mem1.Size / mem1ElementCount; ++i)
            {
                peripheral.Mem1[i].FLAG1 = testCase.FLAG1;
                peripheral.Mem1[i].FLAG2 = testCase.FLAG2;
                peripheral.Mem1[i].VALUE1 = testCase.VALUE1;
                peripheral.Mem1[i].VALUE2 = testCase.VALUE2;
            }

            for(long i = 0; i < peripheral.Mem1.Size / 4; ++i)
            {
                var word = (peripheral as IDoubleWordPeripheral)
                    .ReadDoubleWord(mem1Offset + i * 4);
                Assert.AreEqual(testCase.Memory & mem1RegMask, word & mem1RegMask);
            }
        }

        private Peripherals.Mocks.Mem1Peripheral peripheral;
        long mem1Offset = 0x10;
        long mem1ElementCount = 4;
        long mem1RegMask = 0x3fff_ffff;
    }
}
