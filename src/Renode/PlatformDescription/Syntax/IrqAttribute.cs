//
// Copyright (c) 2010-2019 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System.Collections.Generic;
using System.Linq;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class IrqAttribute : Attribute
    {
        public IrqAttribute(IEnumerable<SingleOrMultiIrqEnd> sources, IEnumerable<IrqDestinations> destinations)
        {
            Sources = sources;
            Destinations = destinations;
        }

        public IrqAttribute SingleAttributeWithInheritedPosition(SingleOrMultiIrqEnd source, IrqReceiver destinationPeripheral, SingleOrMultiIrqEnd destination)
        {
            var copy = SerializationProvider.Instance.DeepClone(this);
            copy.Sources = new[] { source };
            copy.Destinations = new[] { new IrqDestinations(destinationPeripheral, new[] { destination }) };
            return copy;
        }

        public void SetDefaultSource(string propertyName)
        {
            Sources = new[] { new SingleOrMultiIrqEnd(new[] { new IrqEnd(propertyName, 0) }) };
        }

        public override string ToString()
        {
            if(Sources == null)
            {
                return "";
            }
            return $"{Sources.Select(x => x.ToString()).Aggregate((x, y) => x + "," + y)} -> {PrettyPrintDestinations(Destinations)}";
        }

        public override IEnumerable<object> Visit()
        {
            var sourceOrEmpty = Sources ?? Enumerable.Empty<SingleOrMultiIrqEnd>();
            if(Destinations != null)
            {
                return sourceOrEmpty.Cast<object>().Concat(Destinations);
            }
            return sourceOrEmpty;
        }

        public IEnumerable<SingleOrMultiIrqEnd> Sources { get; private set; }

        public IEnumerable<IrqDestinations> Destinations { get; private set; }

        private static string PrettyPrintDestinations(IEnumerable<IrqDestinations> destinations)
        {
            if(destinations.Count() == 1)
            {
                return destinations.ToString();
            }
            return destinations.Select(x => x.ToString()).Aggregate((x, y) => x + " | " + y);
        }
    }
}