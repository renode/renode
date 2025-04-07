//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

using Antmicro.Renode.PlatformDescription.Syntax;

using Sprache;

namespace Antmicro.Renode.PlatformDescription
{
    public sealed class VariableStore
    {
        public VariableStore()
        {
            globalVariables = new Dictionary<string, Variable>();
            localVariables = new Dictionary<Tuple<string, string>, Variable>();
        }

        public void AddBuiltinOrAlreadyRegisteredVariable(string name, object value)
        {
            var variable = new Variable(value.GetType(), DeclarationPlace.BuiltinOrAlreadyRegistered) { Value = value };
            globalVariables.Add(name, variable);
        }

        public Variable DeclareVariable(string name, Type type, Position position, bool local = false)
        {
            var variable = new Variable(type, new DeclarationPlace(position, CurrentScope));
            if(local)
            {
                localVariables.Add(Tuple.Create(CurrentScope, name), variable);
                return variable;
            }
            globalVariables.Add(name, variable);
            return variable;
        }

        public bool TryGetVariableInLocalScope(string name, out Variable variable)
        {
            return globalVariables.TryGetValue(name, out variable) || localVariables.TryGetValue(Tuple.Create(CurrentScope, name), out variable);
        }

        public Variable GetVariableInLocalScope(string name)
        {
            Variable result;
            if(!TryGetVariableInLocalScope(name, out result))
            {
                throw new KeyNotFoundException(string.Format("No variable named '{0}' in local scope.", name));
            }
            return result;
        }

        public bool TryGetVariableFromReference(ReferenceValue reference, out Variable variable)
        {
            return globalVariables.TryGetValue(reference.Value, out variable) ||
                                  localVariables.TryGetValue(Tuple.Create(reference.Scope, reference.Value), out variable);
        }

        public Variable GetVariableFromReference(ReferenceValue reference)
        {
            Variable result;
            if(!TryGetVariableFromReference(reference, out result))
            {
                throw new KeyNotFoundException(string.Format("No variable from reference '{0}'.", reference));
            }
            return result;
        }

        public IEnumerable<Entry> GetMergedEntries()
        {
            var result = new List<Entry>();
            foreach(var variable in globalVariables.Select(x => x.Value).Concat(localVariables.Select(x => x.Value)))
            {
                var mergedEntry = variable.GetMergedEntry();
                if(mergedEntry != null)
                {
                    result.Add(mergedEntry);
                }
            }
            return result;
        }

        public void Clear()
        {
            CurrentScope = null;
            globalVariables.Clear();
            localVariables.Clear();
        }

        public string CurrentScope { get; set; }

        private readonly Dictionary<string, Variable> globalVariables;
        private readonly Dictionary<Tuple<string, string>, Variable> localVariables;
    }
}