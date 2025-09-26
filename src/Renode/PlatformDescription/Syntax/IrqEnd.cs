//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public sealed class IrqEnd
    {
        public IrqEnd(string propertyName, int number)
        {
            PropertyName = propertyName;
            Number = number;
        }

        public override string ToString()
        {
            return string.Format("[IrqEnd: {0}]", ToShortString());
        }

        public string ToShortString()
        {
            return PropertyName ?? Number.ToString();
        }

        public override bool Equals(object obj)
        {
            var other = obj as IrqEnd;
            if(other == null)
            {
                return false;
            }
            return PropertyName == other.PropertyName && Number == other.Number;
        }

        public override int GetHashCode()
        {
            return (11 * 19 * (PropertyName ?? "").GetHashCode()) * 19 + Number.GetHashCode();
        }

        public string PropertyName { get; private set; }

        public int Number { get; private set; }

        public static bool operator ==(IrqEnd a, IrqEnd b)
        {
            if((object)a == null)
            {
                return (object)b == null;
            }
            return a.Equals(b);
        }

        public static bool operator !=(IrqEnd a, IrqEnd b)
        {
            return !(a == b);
        }
    }

    // the class is there because we are not able to have position aware IEnumerable
}