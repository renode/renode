//
// Copyright (c) 2010-2017 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System.Collections.Generic;
using System.Linq;
using Antmicro.Migrant;
using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class IrqAttribute : Attribute
    {
        public IrqAttribute(IEnumerable<SingleOrMultiIrqEnd> sources, IrqDestination destinationPeripheral, IEnumerable<SingleOrMultiIrqEnd> destinations)
        {
            Sources = sources;
            DestinationPeripheral = destinationPeripheral;
            Destinations = destinations;
        }

        public IrqAttribute SingleAttributeWithInheritedPosition(SingleOrMultiIrqEnd source, IrqDestination destinationPeripheral, SingleOrMultiIrqEnd destination)
        {
            var copy = SerializationProvider.Instance.DeepClone(this);
            copy.Sources = new[] { source };
            copy.DestinationPeripheral = destinationPeripheral;
            copy.Destinations = new[] { destination };
            return copy;
        }

        public void SetDefaultSource(string propertyName)
        {
            Sources = new[] { new SingleOrMultiIrqEnd(new[] { new IrqEnd(propertyName, 0) }) };
        }

        public override string ToString()
        {
            return string.Format("[IrqAttribute: {0} -> {1}@{2}]",
                                 Sources == null ? "" : PrettyPrintIrqEnds(Sources.SelectMany(x => x.Ends)),
                                 DestinationPeripheral.ToShortString(),
                                 PrettyPrintIrqEnds(Destinations.SelectMany(x => x.Ends)));
        }

        public override IEnumerable<object> Visit()
        {
            var sourceOrEmpty = Sources ?? Enumerable.Empty<SingleOrMultiIrqEnd>();
            if(Destinations != null)
            {
                return sourceOrEmpty.Cast<object>().Concat(Destinations).Concat(new[] { DestinationPeripheral });
            }
            return sourceOrEmpty;
        }

        public IEnumerable<SingleOrMultiIrqEnd> Sources { get; private set; }
        public IEnumerable<SingleOrMultiIrqEnd> Destinations { get; private set; }
        public IrqDestination DestinationPeripheral { get; private set; }

        private static string PrettyPrintIrqEnds(IEnumerable<IrqEnd> ends)
        {
            if(ends.Count() == 1)
            {
                return ends.Single().ToShortString();
            }
            return string.Format("[{0}]", ends.Select(x => x.ToShortString()).Aggregate((x, y) => x + "," + y));
        }
    }
}
