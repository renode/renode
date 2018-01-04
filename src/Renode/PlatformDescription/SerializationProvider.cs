//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.IO;
using Antmicro.Migrant;
using Antmicro.Migrant.Customization;

namespace Antmicro.Renode.PlatformDescription
{
    public class SerializationProvider
    {
        public static SerializationProvider Instance { get; private set; }

        static SerializationProvider()
        {
            Instance = new SerializationProvider();
        }

        private SerializationProvider()
        {
            var settings = new Settings(disableTypeStamping: true);
            serializer = new Serializer(settings);
            memoryStream = new MemoryStream();
        }

        public T DeepClone<T>(T obj)
        {
            memoryStream.Seek(0, SeekOrigin.Begin);
            serializer.Serialize(obj, memoryStream);
            memoryStream.Seek(0, SeekOrigin.Begin);
            return serializer.Deserialize<T>(memoryStream);
        }

        private readonly Serializer serializer;
        private readonly MemoryStream memoryStream;
    }
}
