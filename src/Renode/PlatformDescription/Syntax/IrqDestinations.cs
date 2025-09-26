//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System.Collections.Generic;
using System.Linq;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public class IrqDestinations
    {
        public IrqDestinations(IrqReceiver destinationPeripheral, IEnumerable<SingleOrMultiIrqEnd> destinations)
        {
            DestinationPeripheral = destinationPeripheral;
            Destinations = destinations;
        }

        public override string ToString()
        {
            return $"{DestinationPeripheral.ToShortString()}@{PrettyPrintIrqEnds(Destinations.SelectMany(x => x.Ends))}";
        }

        public IrqReceiver DestinationPeripheral { get; private set; }

        public IEnumerable<SingleOrMultiIrqEnd> Destinations { get; private set; }

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