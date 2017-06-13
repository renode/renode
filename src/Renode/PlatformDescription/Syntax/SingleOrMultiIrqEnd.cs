//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//

using System;
using System.Collections.Generic;
using System.Linq;
using Antmicro.Migrant;
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
            var endsAsArray = Ends.ToArray();
            if(endsAsArray.Length < 2)
            {
                return "IRQ: " + endsAsArray[0].ToShortString();
            }
            return "IRQs: " + endsAsArray.Select(x => x.ToShortString()).Aggregate((x, y) => x + ',' + y);
        }

        public IEnumerable<object> Visit()
        {
            return Enumerable.Empty<object>();
        }

        public Position StartPosition { get; private set; }
        public int Length { get; private set; }
        public IEnumerable<IrqEnd> Ends { get; private set; }
    }
}
