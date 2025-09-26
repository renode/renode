//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.IO;

using Antmicro.Migrant;
using Antmicro.Migrant.Customization;

namespace Antmicro.Renode.PlatformDescription
{
    public class SerializationProvider
    {
        static SerializationProvider()
        {
            Instance = new SerializationProvider();
        }

        public static SerializationProvider Instance { get; private set; }

        public T DeepClone<T>(T obj)
        {
            memoryStream.Seek(0, SeekOrigin.Begin);
            serializer.Serialize(obj, memoryStream);
            memoryStream.Seek(0, SeekOrigin.Begin);
            return serializer.Deserialize<T>(memoryStream);
        }

        private SerializationProvider()
        {
            var settings = new Settings(disableTypeStamping: true);
            serializer = new Serializer(settings);
            memoryStream = new MemoryStream();
        }

        private readonly Serializer serializer;
        private readonly MemoryStream memoryStream;
    }
}