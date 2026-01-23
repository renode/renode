//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

using Sprache;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public class Entry : IPositionAware<Entry>, IWithPosition, IPrefixable, IScriptable
    {
        public Entry(string variableName, StringWithPosition type, IEnumerable<RegistrationInfo> registrationInfo, IEnumerable<Attribute> attributes, bool isLocal, StringWithPosition alias)
        {
            VariableName = variableName;
            baseVariableName = variableName;
            Type = type;
            RegistrationInfos = registrationInfo;
            Attributes = attributes;
            IsLocal = isLocal;
            Alias = alias;

            foreach(var attribute in attributes)
            {
                attribute.OriginalEntry = this;
            }
        }

        public Entry SetPos(Position startPos, int length)
        {
            var copy = SerializationProvider.Instance.DeepClone(this);
            copy.StartPosition = startPos;
            copy.Length = length;
            return copy;
        }

        public void Prefix(string with)
        {
            VariableName = with + baseVariableName;
        }

        public Entry MergeWith(Entry entry)
        {
            if(Type != null && entry.Type != null && Type.Value != entry.Type.Value)
            {
                throw new InvalidOperationException($"Internal error during entry merge: merging entries of different types: {entry.Type?.Value} and {Type?.Value}.");
            }
            if(entry.VariableName != VariableName || entry.Variable != null || Variable != null)
            {
                throw new InvalidOperationException($"Internal error during entry merge: merging entries for different variables: {entry.VariableName} and {VariableName}.");
            }
            if(entry.Type != null)
            {
                Type = entry.Type;
            }
            if(entry.RegistrationInfos != null)
            {
                RegistrationInfos = entry.RegistrationInfos;
                Alias = entry.Alias;
            }
            if(entry.Attributes == null || Attributes == null)
            {
                Attributes = Attributes ?? entry.Attributes;
            }
            else
            {
                var mergedAttributes = new List<Attribute>();
                // add all ctor and property attributes we don't have in the second entry
                mergedAttributes.AddRange(Attributes.OfType<ConstructorOrPropertyAttribute>()
                                          .Where(x => !entry.Attributes.OfType<ConstructorOrPropertyAttribute>().Any(y => y.Name == x.Name)));
                // then all attributes from second entry
                mergedAttributes.AddRange(entry.Attributes.OfType<ConstructorOrPropertyAttribute>());

                // add all interrupts from both entries for validation and flattening later
                mergedAttributes.AddRange(Attributes.OfType<IrqAttribute>());
                mergedAttributes.AddRange(entry.Attributes.OfType<IrqAttribute>());

                var ourInit = Attributes.OfType<InitAttribute>().SingleOrDefault();
                var theirInit = entry.Attributes.OfType<InitAttribute>().SingleOrDefault();
                if(ourInit == null ^ theirInit == null)
                {
                    mergedAttributes.Add(ourInit ?? theirInit);
                }
                else if(ourInit != null)
                {
                    mergedAttributes.Add(ourInit.Merge(theirInit));
                }

                var ourReset = Attributes.OfType<ResetAttribute>().SingleOrDefault();
                var theirReset = entry.Attributes.OfType<ResetAttribute>().SingleOrDefault();
                if(ourReset == null ^ theirReset == null)
                {
                    mergedAttributes.Add(ourReset ?? theirReset);
                }
                else if(ourReset != null)
                {
                    mergedAttributes.Add(ourReset.Merge(theirReset));
                }

                Attributes = mergedAttributes;
            }
            return this;
        }

        public void FlattenIrqAttributes()
        {
            // one must (and should) flatten attributes after merge, iterating in reverse order to have
            // attributes defined later override those defined earlier
            var multiplexedAttributes = Attributes.OfType<IrqAttribute>().Reverse();
            var result = new List<IrqAttribute>();
            var usedSources = new HashSet<SingleOrMultiIrqEnd>();
            Func<SingleOrMultiIrqEnd, IEnumerable<SingleOrMultiIrqEnd>> selector = x => x.Ends.Select(y => x.WithEnds(new[] { y }));
            foreach(var multiplexedAttribute in multiplexedAttributes)
            {
                var sourcesAsArray = multiplexedAttribute.Sources.SelectMany(selector).ToArray();
                var sourcesUsedInThisAttribute = new HashSet<SingleOrMultiIrqEnd>();
                foreach(var attribute in multiplexedAttribute.Destinations)
                {
                    // Irq -> none
                    if(attribute.DestinationPeripheral == null)
                    {
                        foreach(var source in sourcesAsArray)
                        {
                            result.Add(multiplexedAttribute.SingleAttributeWithInheritedPosition(source, null, null));
                            usedSources.Add(source);
                        }
                        continue;
                    }
                    var destinationsAsArray = attribute.Destinations.SelectMany(selector).ToArray();
                    for(var i = 0; i < sourcesAsArray.Length; i++)
                    {
                        if(!usedSources.Contains(sourcesAsArray[i]))
                        {
                            result.Add(multiplexedAttribute.SingleAttributeWithInheritedPosition(sourcesAsArray[i], attribute.DestinationPeripheral, destinationsAsArray[i]));
                            sourcesUsedInThisAttribute.Add(sourcesAsArray[i]);
                        }
                    }
                }
                usedSources.UnionWith(sourcesUsedInThisAttribute);
            }
            Attributes = Attributes.Except(multiplexedAttributes).Concat(result).ToArray();
        }

        public Entry MakeShallowCopy()
        {
            return new Entry(VariableName, Type, RegistrationInfos, Attributes, IsLocal, Alias);
        }

        public string VariableName { get; private set; }

        public StringWithPosition Type { get; private set; }

        public IEnumerable<RegistrationInfo> RegistrationInfos { get; private set; }

        public IEnumerable<Attribute> Attributes { get; private set; }

        public bool IsLocal { get; private set; }

        public Position StartPosition { get; private set; }

        public int Length { get; private set; }

        public StringWithPosition Alias { get; private set; }

        public ConstructorInfo Constructor { get; set; }

        public Variable Variable { get; set; }

        private readonly string baseVariableName;
    }
}
