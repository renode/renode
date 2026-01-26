//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System.Collections.Generic;
using System.Linq;

using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    // the class is there because we are not able to have position aware IEnumerable
    public sealed class SingleOrMultiIrqEnd : IPositionAware<SingleOrMultiIrqEnd>, IWithPosition, IVisitable
    {
        public SingleOrMultiIrqEnd(IEnumerable<IrqEnd> ends)
        {
            Ends = ends;
        }

        public SingleOrMultiIrqEnd SetPos(Position startPos, int length)
        {
            var copy = SerializationProvider.Instance.DeepClone(this);
            copy.StartPosition = startPos;
            copy.Length = length;
            return copy;
        }

        public SingleOrMultiIrqEnd WithEnds(IEnumerable<IrqEnd> ends)
        {
            var copy = SerializationProvider.Instance.DeepClone(this);
            copy.Ends = ends;
            return copy;
        }

        public override string ToString()
        {
            return PrettyPrintEnds(Ends);
        }

        public override bool Equals(object obj)
        {
            return obj is SingleOrMultiIrqEnd end && Enumerable.SequenceEqual(Ends, end.Ends);
        }

        public override int GetHashCode()
        {
            var code = 19;
            foreach(var end in Ends)
            {
                code = code * 31 + end.GetHashCode();
            }
            return code;
        }

        public IEnumerable<object> Visit()
        {
            return Enumerable.Empty<object>();
        }

        public Position StartPosition { get; private set; }

        public int Length { get; private set; }

        public IEnumerable<IrqEnd> Ends { get; private set; }

        private static string PrettyPrintEnds(IEnumerable<IrqEnd> ends)
        {
            var endsAsArray = ends.ToArray();
            if(endsAsArray.Length < 2)
            {
                return endsAsArray[0].ToShortString();
            }
            return $"[{endsAsArray.Select(x => x.ToShortString()).Aggregate((x, y) => x + ',' + y)}]";
        }
    }
}
