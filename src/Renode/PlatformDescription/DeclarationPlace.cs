//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

using System;
using System.Collections.Generic;
using Sprache;

namespace Antmicro.Renode.PlatformDescription
{

    public sealed class DeclarationPlace
    {
        static DeclarationPlace()
        {
            BuiltinOrAlreadyRegistered = new DeclarationPlace();
        }

        public static DeclarationPlace BuiltinOrAlreadyRegistered { get; private set; }

        public DeclarationPlace(Position position, string file)
        {
            Position = position;
            File = file;
        }

        private DeclarationPlace()
        {
        }

        public string GetFriendlyDescription()
        {
            if(this == BuiltinOrAlreadyRegistered)
            {
                return "builtin";
            }
            return string.Format("at {2}{0}:{1}", Position.Line, Position.Column, File == "" ? "" : File + ':');
        }

        public override string ToString()
        {
            return string.Format("[DeclarationPlace: Position={0}, File={1}]", Position, File);
        }

        public Position Position { get; private set; }
        public string File { get; private set; }
    }

}
