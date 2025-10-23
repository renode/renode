//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Core.Structure;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.Miscellaneous;
using Antmicro.Renode.PlatformDescription.Syntax;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Utilities.Collections;

using Sprache;

using Range = Antmicro.Renode.Core.Range;

namespace Antmicro.Renode.PlatformDescription
{
    using DependencyGraph = Dictionary<Entry, Dictionary<Entry, ReferenceValue>>;

    public sealed partial class CreationDriver
    {
        public CreationDriver(Machine machine, IUsingResolver usingResolver, IScriptHandler scriptHandler)
        {
            this.usingResolver = usingResolver;
            this.machine = machine;
            this.scriptHandler = scriptHandler;
            variableStore = new VariableStore();
            processedDescriptions = new List<Description>();
            objectValueUpdateQueue = new Queue<ObjectValue>();
            objectValueInitQueue = new Queue<ObjectValue>();
            usingsBeingProcessed = new Stack<string>();
            irqCombiners = new Dictionary<IrqDestination, IrqCombinerConnection>();
            createdDisposables = new List<IDisposable>();
            PrepareVariables();
        }

        public void ProcessDescription(string description)
        {
            ProcessInner("", description);
        }

        public void ProcessFile(string path)
        {
            if(!File.Exists(path))
            {
                throw new RecoverableException(string.Format("Could not find file '{0}'.", path));
            }
            var source = File.ReadAllText(path);
            usingsBeingProcessed.Push(Path.GetFullPath(path)); // don't need to pop since stack is cleared within ProcessInner
            ProcessInner(path, source);
        }

        private static string GetTypeListing(Type[] typesToAssign)
        {
            return typesToAssign.Length == 1 ? string.Format("type '{0}'", typesToAssign[0])
                                                   : "possible types " + typesToAssign.Select(x => string.Format("'{0}'", x.Name)).Aggregate((x, y) => x + ", " + y);
        }

        private static string GetFriendlyConstructorName(ConstructorInfo ctor)
        {
            var parameters = ctor.GetParameters();
            if(parameters.Length == 0)
            {
                return string.Format("{0} with no parameters", ctor.DeclaringType);
            }
            return string.Format("{0} with the following parameters: [{1}]", ctor.DeclaringType, parameters.Select(x => x.ParameterType + (x.HasDefaultValue ? " (optional)" : ""))
                                 .Aggregate((x, y) => x + ", " + y));
        }

        private static IEnumerable<PropertyInfo> GetGpioProperties(Type type)
        {
            return type.GetProperties(BindingFlags.Public | BindingFlags.Instance).Where(x => typeof(GPIO).IsAssignableFrom(x.PropertyType));
        }

        private static string GetValidEnumValues(Type expectedType)
        {
            var validValues = new StringBuilder();
            foreach(var field in Enum.GetValues(expectedType))
            {
                validValues.AppendLine($"       {expectedType.Name}.{field},");
            }
            return validValues.ToString();
        }

        private void ProcessVariableDeclarations(Description description, string prefix)
        {
            // Collect all variable declarations (entries where there is a type specified).
            // These can be anywhere in the usings hierarchy, as long as there is only one.
            var entries = description.Entries;
            foreach(var entry in entries)
            {
                if(entry.Type != null)
                {
                    var wasDeclared = variableStore.TryGetVariableInLocalScope(entry.VariableName, out var variable);
                    if(!wasDeclared)
                    {
                        var resolved = ResolveTypeOrThrow(entry.Type, entry.Type);
                        variable = variableStore.DeclareVariable(entry.VariableName, resolved, entry.StartPosition, entry.IsLocal);
                    }
                    else
                    {
                        HandleDoubleDeclarationError(variable, entry);
                    }
                }
            }
        }

        private void CollectVariableEntries(Description description, string prefix)
        {
            // Having collected all variable declarations, go through the entries again and collect them in the correct
            // order for merging later.
            // At this point we can also validate if there were declaration errors (e. g. variable without type).
            var entries = description.Entries;

            foreach(var entry in entries)
            {
                if(!entry.Attributes.Any() && entry.RegistrationInfos == null && entry.Type == null)
                {
                    HandleError(ParsingError.EmptyEntry, entry, "Entry cannot be empty.", false);
                }

                var wasDeclared = variableStore.TryGetVariableInLocalScope(entry.VariableName, out var variable);
                if(!wasDeclared)
                {
                    HandleError(ParsingError.VariableNeverDeclared, entry,
                                    string.Format("Variable '{0}' is never declared - type is unknown.", entry.VariableName), false);
                }

                if(entry.Type == null)
                {
                    var updatingCtorAttribute = entry.Attributes.OfType<ConstructorOrPropertyAttribute>().FirstOrDefault(x => !x.IsPropertyAttribute);
                    if(updatingCtorAttribute != null)
                    {
                        var position = GetFormattedPosition(updatingCtorAttribute);
                        Logger.Log(LogLevel.Debug, "At {0}: updating constructors of the entry declared earlier.", position);
                    }
                }

                variable.AddEntry(entry);
            }

            foreach(var entry in entries)
            {
                ProcessEntryPreMerge(entry);
            }
        }

        private void HandleDoubleDeclarationError(Variable variable, Entry entry)
        {
            string restOfErrorMessage;
            if(variable.DeclarationPlace != DeclarationPlace.BuiltinOrAlreadyRegistered)
            {
                restOfErrorMessage = string.Format(", previous declaration was {0}", variable.DeclarationPlace.GetFriendlyDescription());
            }
            else
            {
                restOfErrorMessage = " as an already registered peripheral or builtin";
            }
            HandleError(ParsingError.VariableAlreadyDeclared, entry,
                        string.Format("Variable '{0}' was already declared{1}.", entry.VariableName, restOfErrorMessage), false);
        }

        private void ProcessInner(string file, string source)
        {
            try
            {
                var usingsGraph = new UsingsGraph(this, file, source);
                usingsGraph.TraverseDepthFirst(ProcessVariableDeclarations);
                usingsGraph.TraverseDepthFirst(CollectVariableEntries);
                var mergedEntries = variableStore.GetMergedEntries();
                foreach(var entry in mergedEntries)
                {
                    ProcessEntryPostMerge(entry);
                }

                var sortedForCreation = SortEntriesForCreation(mergedEntries);
                var irqConnectionCount = new Dictionary<IrqDestination, int>();
                foreach(var entry in sortedForCreation)
                {
                    CreateFromEntry(entry);

                    var irqs = entry.Attributes.OfType<IrqAttribute>()
                        .SelectMany(attr => attr.Destinations)
                        .Where(dest => dest.DestinationPeripheral != null);
                    foreach(var irq in irqs)
                    {
                        var destinationPeripheralName = irq.DestinationPeripheral.Reference.Value;
                        var destinationLocalIndex = irq.DestinationPeripheral.LocalIndex;
                        var destinationIndex = irq.Destinations.Single().Ends.Single().Number;
                        var key = new IrqDestination(destinationPeripheralName, destinationLocalIndex, destinationIndex);
                        if(!irqConnectionCount.TryGetValue(key, out var count))
                        {
                            count = 0;
                        }
                        irqConnectionCount[key] = count + 1;
                    }
                }

                foreach(var pair in irqConnectionCount.Where(pair => pair.Value > 1))
                {
                    irqCombiners[pair.Key] = new IrqCombinerConnection(new CombinedInput(pair.Value));
                }

                foreach(var entry in sortedForCreation)
                {
                    SetPropertiesAndConnectInterrupts(entry.Variable.Value, entry.Attributes);
                }
                UpdatePropertiesAndInterruptsOnUpdateQueue();

                var sortedForRegistration = SortEntriesForRegistration(mergedEntries);
                var entriesToRegister = sortedForRegistration.Where(x => x.RegistrationInfos != null);
                do
                {
                    var numberOfEntriesToRegisterBefore = entriesToRegister.Count();
                    entriesToRegister = RegisterFromEntries(entriesToRegister);
                    var numberOfEntriesToRegisterAfter = entriesToRegister.Count();
                    if(numberOfEntriesToRegisterBefore != 0 && numberOfEntriesToRegisterBefore == numberOfEntriesToRegisterAfter)
                    {
                        // If there was no progress, it must have been due to 'AreAllParentsRegistered' returning false
                        // and up to that point backtraced methods between 'AreAllParentsRegistered' and 'RegisterFromEntries'
                        // are re-entrant so deadlock can't be resolved by retrying with the same collection of entries.
                        var entry = entriesToRegister.First();
                        var registrationInfoRegisters = entry.RegistrationInfos.Select(x => $"'{x.Register.Value}'");
                        HandleError(ParsingError.RegistrationException, entry,
                                string.Format("Unable to finish the registration of '{0}'. Are all parents: {1}, registered?",
                                              entry.VariableName, Misc.PrettyPrintCollection<string>(registrationInfoRegisters)), false);
                    }
                } while(entriesToRegister.Any());

                while(objectValueInitQueue.Count > 0)
                {
                    var objectValue = objectValueInitQueue.Dequeue();
                    scriptHandler.Execute(objectValue, objectValue.Attributes.OfType<InitAttribute>().Single().Lines,
                                        x => HandleInitSectionError(x, objectValue));
                }
                foreach(var entry in sortedForRegistration)
                {
                    var initAttribute = entry.Attributes.OfType<InitAttribute>().SingleOrDefault();
                    if(initAttribute != null)
                    {
                        scriptHandler.Execute(entry, initAttribute.Lines, x => HandleInitSectionError(x, entry));
                    }

                    var resetAttribute = entry.Attributes.OfType<ResetAttribute>().SingleOrDefault();
                    if(resetAttribute != null)
                    {
                        scriptHandler.RegisterReset(entry, resetAttribute.Lines, x =>
                            HandleError(ParsingError.ResetSectionRegistrationError, resetAttribute, x, false));
                    }
                }
            }
            finally
            {
                variableStore.Clear();
                processedDescriptions.Clear();
                objectValueUpdateQueue.Clear();
                objectValueInitQueue.Clear();
                usingsBeingProcessed.Clear();
                irqCombiners.Clear();
                createdDisposables.Clear();
                PrepareVariables();
            }
            machine.PostCreationActions();
        }

        private Description ParseDescription(string description, string fileName)
        {
            var output = PreLexer.Process(description, fileName).Aggregate((x, y) => x + Environment.NewLine + y);
            var input = new Input(output);
            var result = Grammar.Description(input);
            if(!result.WasSuccessful)
            {
                var message = "Syntax error, " + result.Message;
                if(result.Expectations.Any())
                {
                    message += string.Format("; expected {0}", result.Expectations.Aggregate((x, y) => x + " or " + y));
                }
                HandleError(ParsingError.SyntaxError, WithPositionForSyntaxErrors.FromResult(result, fileName, description), message, false);
            }
            result.Value.FileName = fileName;
            result.Value.Source = description;
            return result.Value;
        }

        private void PrepareVariables()
        {
            // machine is always there and is not a peripheral
            variableStore.AddBuiltinOrAlreadyRegisteredVariable(Machine.MachineKeyword, machine);
            var peripherals = machine.GetRegisteredPeripherals().Where(x => !string.IsNullOrEmpty(x.Name)).Select(x => Tuple.Create(x.Peripheral, x.Name)).Distinct().ToDictionary(x => x.Item1, x => x.Item2);
            foreach(var peripheral in peripherals)
            {
                variableStore.AddBuiltinOrAlreadyRegisteredVariable(peripheral.Value, peripheral.Key);
            }
        }

        private List<Entry> SortEntriesForCreation(IEnumerable<Entry> entries)
        {
            var graph = BuildDependencyGraph(entries, creationNotRegistration: true);
            return SortEntries(entries, graph, ParsingError.CreationOrderCycle);
        }

        private List<Entry> SortEntriesForRegistration(IEnumerable<Entry> entries)
        {
            var graph = BuildDependencyGraph(entries, creationNotRegistration: false);
            return SortEntries(entries, graph, ParsingError.RegistrationOrderCycle);
        }

        private List<Entry> SortEntries(IEnumerable<Entry> entries, DependencyGraph graph, ParsingError cycleErrorType)
        {
            var result = new List<Entry>();
            var toVisit = new HashSet<Entry>(entries);
            var stackVisited = new HashSet<Entry>();
            while(toVisit.Count > 0)
            {
                var element = toVisit.First();
                WalkGraph(element, graph, new ReferenceValueStack(null, null, element), stackVisited, result, toVisit, cycleErrorType);
            }
            return result;
        }

        private void WalkGraph(Entry entry, DependencyGraph graph, ReferenceValueStack referenceValueStack,
                               HashSet<Entry> stackVisited, List<Entry> result, HashSet<Entry> toVisit, ParsingError cycleErrorType)
        {
            if(!toVisit.Contains(entry))
            {
                return;
            }
            if(!stackVisited.Add(entry))
            {
                // we have a cycle, let's find the path
                var last = referenceValueStack;
                var path = new Stack<ReferenceValueStack>();
                path.Push(referenceValueStack);
                referenceValueStack = referenceValueStack.Previous;
                while(last.Value.Value != referenceValueStack.Entry.VariableName)
                {
                    path.Push(referenceValueStack);
                    referenceValueStack = referenceValueStack.Previous;
                }

                var message = new StringBuilder();
                message.Append("Dependency cycle has been found. The path is as follows:");
                ReferenceValueStack pathElement = null;
                while(path.Count > 0)
                {
                    pathElement = path.Pop();
                    message.AppendLine();
                    message.AppendFormat("Entry '{0}' at {1} references '{2}' at {3}.",
                                         pathElement.Previous.Entry.VariableName, GetFormattedPosition(pathElement.Previous.Entry.Type),
                                         pathElement.Value.Value, GetFormattedPosition(pathElement.Value));
                }
                HandleError(cycleErrorType, pathElement.Entry, message.ToString(), false);
            }
            var edgesTo = graph[entry];
            foreach(var edgeTo in edgesTo)
            {
                WalkGraph(edgeTo.Key, graph, new ReferenceValueStack(referenceValueStack, edgeTo.Value, edgeTo.Key), stackVisited, result, toVisit, cycleErrorType);
            }
            stackVisited.Remove(entry);
            result.Add(entry);
            toVisit.Remove(entry);
        }

        // the dependency graph works as follows:
        // it is incidence dictionary, so that if a depends on b, then we have entry in the dictionary
        // for a and this is another dictionary in which there is an entry for b and the value of such entry
        // is a syntax element (ReferenceValue) that states such dependency
        private DependencyGraph BuildDependencyGraph(IEnumerable<Entry> source, bool creationNotRegistration)
        {
            var result = new DependencyGraph();
            foreach(var from in source)
            {
                var localDictionary = new Dictionary<Entry, ReferenceValue>();
                result.Add(from, localDictionary);
                SyntaxTreeHelpers.VisitSyntaxTree<IVisitable>(from, ctorElement =>
                {
                    ReferenceValue maybeReferenceValue;
                    if(ctorElement is ConstructorOrPropertyAttribute ctorAttribute)
                    {
                        if(ctorAttribute.IsPropertyAttribute)
                        {
                            return;
                        }
                        maybeReferenceValue = ctorAttribute.Value as ReferenceValue;
                    }
                    else if(ctorElement is RegistrationInfo ctorRegistrationInfo)
                    {
                        maybeReferenceValue = ctorRegistrationInfo.Register;
                    }
                    else
                    {
                        return;
                    }

                    if(maybeReferenceValue == null)
                    {
                        return;
                    }
                    var referenceValue = maybeReferenceValue;

                    // it is easier to track dependency on variables than on entries (because there is connection refVal -> variable and entry -> variable)
                    var variable = variableStore.GetVariableFromReference(referenceValue);
                    if(variable.DeclarationPlace == DeclarationPlace.BuiltinOrAlreadyRegistered)
                    {
                        return;
                    }
                    var to = source.Single(x => x.Variable.Equals(variable));
                    if(!localDictionary.ContainsKey(to))
                    {
                        // this way we favour shorter paths when tracking dependency
                        localDictionary.Add(to, referenceValue);
                    }
                }, (obj, isChildOfEntry) =>
                {
                    var objAsPropertyOrAttribute = (obj as ConstructorOrPropertyAttribute);
                    var isNotProperty = (objAsPropertyOrAttribute == null) || !objAsPropertyOrAttribute.IsPropertyAttribute;

                    var skipType = creationNotRegistration
                        ? obj is RegistrationInfo
                        : obj is IrqAttribute || obj is ConstructorOrPropertyAttribute;
                    var isNotOfSkippedType = !(isChildOfEntry && skipType);

                    return isNotProperty && isNotOfSkippedType;
                });
            }
            return result;
        }

        private void ProcessEntryPreMerge(Entry entry)
        {
            var entryType = variableStore.GetVariableInLocalScope(entry.VariableName).VariableType;
            if(entry.Alias != null)
            {
                if(entry.RegistrationInfos == null)
                {
                    HandleError(ParsingError.AliasWithoutRegistration, entry.Alias,
                                string.Format("Entry '{0}' has an alias '{1}', while not having a registration info.", entry.VariableName, entry.Alias.Value), true);
                }
                if(entry.RegistrationInfos.First().Register == null)
                {
                    HandleError(ParsingError.AliasWithNoneRegistration, entry.Alias,
                                string.Format("Entry '{0}' has an alias '{1}', while having a none registration info.", entry.VariableName, entry.Alias.Value), true);
                }
            }
            if(entry.RegistrationInfos != null)
            {
                foreach(var registrationInfo in entry.RegistrationInfos)
                {
                    if(registrationInfo.Register == null) // if the register is null, then this is registration canceling entry
                    {
                        break;
                    }
                    Variable registerVariable;
                    if(!variableStore.TryGetVariableFromReference(registrationInfo.Register, out registerVariable))
                    {
                        HandleError(ParsingError.MissingReference, registrationInfo.Register,
                                    string.Format("Undefined register '{0}'.", registrationInfo.Register), true);
                    }

                    var registerInterfaces = registerVariable.VariableType.GetInterfaces().Where(x => x.IsGenericType &&
                                                                                x.GetGenericTypeDefinition() == typeof(IPeripheralRegister<,>)
                                                                                && x.GetGenericArguments()[0].IsAssignableFrom(entryType)).ToArray();
                    if(registerInterfaces.Length == 0)
                    {
                        HandleError(ParsingError.NoUsableRegisterInterface, registrationInfo.Register,
                                    string.Format("Register '{0}' of type '{1}' does not provide an interface to register '{2}' of type '{3}'.",
                                                  registrationInfo.Register.Value, registerVariable.VariableType, entry.VariableName, entryType), true);
                    }

                    var possibleTypes = registerInterfaces.Select(x => x.GetGenericArguments()[1]).ToArray();
                    var registrationPoint = registrationInfo.RegistrationPoint;

                    var usefulRegistrationPointTypes = new List<Type>();

                    var friendlyName = "Registration point";
                    // reference and object values are type checked
                    var referenceRegPoint = registrationPoint as ReferenceValue;
                    var objectRegPoint = registrationPoint as ObjectValue;
                    if(referenceRegPoint != null)
                    {
                        usefulRegistrationPointTypes.AddRange(ValidateReference(friendlyName, possibleTypes, referenceRegPoint));
                    }
                    else if(objectRegPoint != null)
                    {
                        usefulRegistrationPointTypes.AddRange(ValidateObjectValue(friendlyName, possibleTypes, objectRegPoint));
                    }
                    else
                    {
                        // for simple values we try to find a ctor
                        var ctors = FindUsableRegistrationPoints(possibleTypes, registrationPoint);
                        if(ctors.Count == 0)
                        {
                            // fall back to the null registration point if possible
                            if(registrationPoint == null
                                && possibleTypes.Contains(typeof(NullRegistrationPoint)))
                            {
                                usefulRegistrationPointTypes.Add(typeof(NullRegistrationPoint));
                            }
                            else
                            {
                                HandleError(ParsingError.NoCtorForRegistrationPoint, registrationPoint ?? registrationInfo.Register, "Could not find any suitable constructor for this registration point.", true);
                            }
                        }
                        else if(ctors.Count > 1)
                        {
                            HandleError(ParsingError.AmbiguousCtorForRegistrationPoint, registrationPoint ?? registrationInfo.Register,
                                        "Ambiguous choice between constructors for registration point:" + Environment.NewLine +
                                        ctors.Select(x => GetFriendlyConstructorName(x.Item1)).Aggregate((x, y) => x + Environment.NewLine + y), true);
                        }
                        else
                        {
                            registrationInfo.Constructor = ctors[0].Item1;
                            registrationInfo.ConvertedValue = ctors[0].Item2;
                            usefulRegistrationPointTypes.Add(ctors[0].Item1.ReflectedType);
                        }
                    }
                    // our first criterium is registration point type (we seek the most derived), then we check for the registree (peripheral)
                    if(!FindMostDerived(usefulRegistrationPointTypes))
                    {
                        HandleError(ParsingError.AmbiguousRegistrationPointType, registrationInfo.RegistrationPoint,
                                    string.Format("Registration point is ambiguous, at least two types can be used with given value in register '{0}': '{1}' and '{2}'", registrationInfo.Register.Value,
                                                  usefulRegistrationPointTypes[usefulRegistrationPointTypes.Count - 2],
                                                  usefulRegistrationPointTypes[usefulRegistrationPointTypes.Count - 1]), false);
                    }
                    var usefulRegistreeTypes = registerInterfaces.Where(x => x.GenericTypeArguments[1] == usefulRegistrationPointTypes[0]).Select(x => x.GenericTypeArguments[0]).ToList();
                    if(!FindMostDerived(usefulRegistreeTypes))
                    {
                        HandleError(ParsingError.AmbiguousRegistree, registrationInfo.RegistrationPoint,
                                    string.Format("For given registration point of type '{3}', at least two types of registree can be used in register '{0}': '{1}' and '{2}'", registrationInfo.Register.Value,
                                                  usefulRegistreeTypes[usefulRegistreeTypes.Count - 2],
                                                  usefulRegistreeTypes[usefulRegistreeTypes.Count - 1],
                                                  usefulRegistrationPointTypes[0]), false);
                    }
                    registrationInfo.RegistrationInterface = typeof(IPeripheralRegister<,>).MakeGenericType(new[] { usefulRegistreeTypes[0], usefulRegistrationPointTypes[0] });
                }
            }

            if(entry.Attributes == null)
            {
                return;
            }

            var ctorOrPropertyAttributes = entry.Attributes.OfType<ConstructorOrPropertyAttribute>();
            CheckRepeatedCtorAttributes(ctorOrPropertyAttributes);
            CheckRepeatedInitAttributes(entry.Attributes.OfType<InitAttribute>());
            CheckRepeatedResetAttributes(entry.Attributes.OfType<ResetAttribute>());

            foreach(var attribute in entry.Attributes)
            {
                ValidateAttributePreMerge(entryType, attribute);
            }
            // checking overlapping irqs is here because ValidateAttributePreMerge will find sources for default irqs
            // and this method assumes that such operation has already happened
            CheckOverlappingIrqs(entry.Attributes.OfType<IrqAttribute>());

            entry.FlattenIrqAttributes();
        }

        private bool FindMostDerived(List<Type> types)
        {
            while(types.Count > 1)
            {
                var type1 = types[types.Count - 2];
                var type2 = types[types.Count - 1];
                // note that if (*) and (**) are true, then type1 == type2
                if(type1.IsAssignableFrom(type2)) // (*)
                {
                    types.Remove(type1);
                }
                else if(type2.IsAssignableFrom(type1)) // (**)
                {
                    types.Remove(type2);
                }
                else
                {
                    return false;
                }
            }
            return true;
        }

        private void ProcessEntryPostMerge(Entry entry)
        {
            // we have to find a constructor for this entry - if it is to be constructed (e.g. sysbus entry is not)
            // we also have to find constructors for all of the object values within this entry

            if(entry.Type != null)
            {
                entry.Constructor = FindConstructor(entry.Variable.VariableType,
                                                    entry.Attributes.OfType<ConstructorOrPropertyAttribute>().Where(x => !x.IsPropertyAttribute), entry.Type);
            }
            else
            {
                var constructorAttribute = entry.Attributes.OfType<ConstructorOrPropertyAttribute>().FirstOrDefault(x => !x.IsPropertyAttribute);
                if(constructorAttribute != null)
                {
                    HandleError(ParsingError.CtorAttributesInNonCreatingEntry, constructorAttribute, "Constructor attribute within entry for variable that is not created.", false);
                }
            }

            SyntaxTreeHelpers.VisitSyntaxTree<ObjectValue>(entry, objectValue =>
            {
                objectValue.Constructor = FindConstructor(objectValue.ObjectValueType,
                                                          objectValue.Attributes.OfType<ConstructorOrPropertyAttribute>().Where(x => !x.IsPropertyAttribute), objectValue);
            });
            if(entry.Attributes.Any(x => x is InitAttribute))
            {
                ValidateInitSection(entry);
            }
        }

        private void ValidateInitSection(IScriptable scriptable)
        {
            string errorMessage;
            if(!scriptHandler.ValidateInit(scriptable, out errorMessage))
            {
                HandleInitSectionError(errorMessage, scriptable);
            }
        }

        private void HandleInitSectionError(string message, IScriptable scriptable)
        {
            HandleError(ParsingError.InitSectionValidationError, scriptable.Attributes.Single(x => x is InitAttribute), message, false);
        }

        private void CreateFromEntry(Entry entry)
        {
            if(entry.Type == null)
            {
                return;
            }
            var constructor = entry.Constructor;
            entry.Variable.Value = CreateAndHandleError(constructor, entry.Attributes, string.Format("'{0}'", entry.VariableName), entry.Type);
        }

        private object CreateFromObjectValue(ObjectValue value)
        {
            var constructor = value.Constructor;
            var result = CreateAndHandleError(value.Constructor, value.Attributes, string.Format("object value of type '{0}'", value.ObjectValueType.Name), value);
            if(value.Object != null)
            {
                HandleInternalError(value);
            }
            value.Object = result;
            objectValueUpdateQueue.Enqueue(value);
            if(value.Attributes.Any(x => x is InitAttribute))
            {
                objectValueInitQueue.Enqueue(value);
            }
            return result;
        }

        private object CreateAndHandleError(ConstructorInfo constructor, IEnumerable<Syntax.Attribute> attributes, string friendlyName, IWithPosition responsibleSyntaxElement)
        {
            object result = null;
            try
            {
                result = constructor.Invoke(PrepareConstructorParameters(constructor, attributes.OfType<ConstructorOrPropertyAttribute>().Where(x => !x.IsPropertyAttribute)));
            }
            catch(TargetInvocationException exception)
            {
                var constructionException = exception.InnerException as ConstructionException;
                if(constructionException == null)
                {
                    throw;
                }

                var exceptionMessage = new StringBuilder();
                exceptionMessage.AppendLine(constructionException.Message);
                for(var innerException = constructionException.InnerException; innerException != null; innerException = innerException.InnerException)
                {
                    exceptionMessage.AppendLine(innerException.Message);
                }
                var message = string.Format("Exception was thrown during construction of {0}:{1}{2}", friendlyName, Environment.NewLine, exceptionMessage);
                HandleError(ParsingError.ConstructionException, responsibleSyntaxElement, message, false);
            }
            if(result is IDisposable disposable)
            {
                createdDisposables.Add(disposable);
            }
            return result;
        }

        private void UpdatePropertiesAndInterruptsOnUpdateQueue()
        {
            while(objectValueUpdateQueue.Count > 0)
            {
                var objectValue = objectValueUpdateQueue.Dequeue();
                SetPropertiesAndConnectInterrupts(objectValue.Object, objectValue.Attributes);
            }
        }

        private object[] PrepareConstructorParameters(ConstructorInfo constructor, IEnumerable<ConstructorOrPropertyAttribute> attributes)
        {
            var parameters = constructor.GetParameters();
            var parameterValues = new object[parameters.Length];
            for(var i = 0; i < parameters.Length; i++)
            {
                var parameter = parameters[i];
                var attribute = attributes.SingleOrDefault(x => ParameterNameMatches(x.Name, parameter, silent: true));
                if(attribute == null)
                {
                    FillDefaultParameter(ref parameterValues[i], parameter);
                    continue;
                }

                if(TryConvertSimpleValue(parameter.ParameterType, attribute.Value, out parameterValues[i], silent: true).ResultType == ConversionResultType.ConversionSuccessful)
                {
                    continue;
                }
                var referenceValue = attribute.Value as ReferenceValue;
                if(referenceValue != null)
                {
                    parameterValues[i] = variableStore.GetVariableFromReference(referenceValue).Value;
                    if(parameterValues[i] == null)
                    {
                        HandleInternalError(referenceValue); // should not be null at this point
                    }
                    continue;
                }
                var objectValue = attribute.Value as ObjectValue;
                if(objectValue != null)
                {
                    parameterValues[i] = CreateFromObjectValue(objectValue);
                    continue;
                }
                HandleInternalError(); // should not reach here
            }
            return parameterValues;
        }

        private void FillDefaultParameter(ref object destination, ParameterInfo parameter)
        {
            if(parameter.HasDefaultValue)
            {
                destination = parameter.DefaultValue;
            }
            else
            {
                if(!TryGetValueOfOurDefaultParameter(parameter.ParameterType, out destination))
                {
                    HandleInternalError();
                }
            }
        }

        private List<Tuple<ConstructorInfo, object>> FindUsableRegistrationPoints(Type[] registrationPointTypes, Value value)
        {
            var result = new List<Tuple<ConstructorInfo, object>>();
            foreach(var type in registrationPointTypes)
            {
                IEnumerable<ConstructorInfo> ctors = type.GetConstructors();

                if(value == null)
                {
                    ctors = ctors.Where(x => !x.GetParameters().TakeWhile(y => !y.HasDefaultValue).Any());
                    result.AddRange(ctors.Select(x => Tuple.Create(x, (object)null)));
                }
                else
                {
                    ctors = ctors.Where(x =>
                    {
                        var parameters = x.GetParameters();
                        if(parameters.Length == 0)
                        {
                            return false;
                        }
                        if(parameters.Length == 1)
                        {
                            return true;
                        }
                        return parameters[1].HasDefaultValue; // if second is optional, all other are optional
                    });
                    foreach(var ctor in ctors)
                    {
                        var firstParamType = ctor.GetParameters()[0].ParameterType;
                        object convertedValue;
                        var conversionResult = TryConvertSimpleValue(firstParamType, value, out convertedValue);
                        switch(conversionResult.ResultType)
                        {
                        case ConversionResultType.ConversionSuccessful:
                            result.Add(Tuple.Create(ctor, convertedValue));
                            break;
                        case ConversionResultType.ConversionNotApplied:
                            HandleInternalError(value); // should not reach here
                            break;
                        }
                    }
                }
            }
            return result.Distinct().ToList();
        }

        private void SetPropertiesAndConnectInterrupts(object objectToSetOn, IEnumerable<Syntax.Attribute> attributes)
        {
            var objectType = objectToSetOn.GetType();

            var propertyAttributes = attributes.OfType<ConstructorOrPropertyAttribute>().Where(x => x.IsPropertyAttribute);
            foreach(var attribute in propertyAttributes)
            {
                if(attribute.Value == null)
                {
                    continue;
                }
                try
                {
                    attribute.Property.GetSetMethod().Invoke(objectToSetOn, new[] { ConvertFromValue(attribute.Property.PropertyType, attribute.Value) });
                }
                catch(TargetInvocationException exception)
                {
                    var recoverableException = exception.InnerException as RecoverableException;
                    if(recoverableException == null)
                    {
                        throw;
                    }
                    HandleError(ParsingError.PropertySettingException, attribute, string.Format("Exception was thrown when setting property '{0}'", attribute.Name), false);
                }
            }

            var irqAttributes = attributes.OfType<IrqAttribute>();
            foreach(var multiplexedAttributes in irqAttributes)
            {
                foreach(var attribute in multiplexedAttributes.Destinations)
                {
                    if(attribute.DestinationPeripheral == null)
                    {
                        // irq -> none case, we can simply ignore it
                        continue;
                    }
                    // at this moment all irq attributes are of simple type (i.e. a->b@c)
                    var destinationReference = attribute.DestinationPeripheral.Reference;
                    var destination = variableStore.GetVariableFromReference(destinationReference).Value;

                    IGPIO source;
                    IGPIOReceiver destinationReceiver;

                    var irqEnd = multiplexedAttributes.Sources.Single().Ends.Single();
                    if(irqEnd.PropertyName != null)
                    {
                        source = (IGPIO)GetGpioProperties(objectType).Single(x => x.Name == irqEnd.PropertyName).GetValue(objectToSetOn);

                        if(source == null)
                        {
                            HandleError(ParsingError.UninitializedSourceIrqObject, multiplexedAttributes,
                                        $"{objectToSetOn} has uninitialized IRQ object {irqEnd.PropertyName}", false);
                            continue;
                        }
                    }
                    else
                    {
                        // any manual irq connection should remove all automatic connections
                        if(objectToSetOn is IHasAutomaticallyConnectedGPIOOutputs objectWithAutomaticConnections)
                        {
                            objectWithAutomaticConnections.DisconnectAutomaticallyConnectedGPIOOutputs();
                        }
                        var connections = ((INumberedGPIOOutput)objectToSetOn).Connections;
                        if(!connections.ContainsKey(irqEnd.Number))
                        {
                            HandleError(ParsingError.IrqSourcePinDoesNotExist, multiplexedAttributes,
                                        $"{objectToSetOn} doesn't have IRQ {irqEnd.Number}.\nAvailable IRQs: {Misc.PrettyPrintCollection(connections.Keys)}.", false);
                            continue;
                        }
                        source = connections[irqEnd.Number];

                        if(source == null)
                        {
                            HandleError(ParsingError.UninitializedSourceIrqObject, multiplexedAttributes,
                                        $"{objectToSetOn} has uninitialized IRQ {irqEnd.Number}", false);
                            continue;
                        }
                    }

                    var localIndex = attribute.DestinationPeripheral.LocalIndex;
                    var index = attribute.Destinations.Single().Ends.Single().Number;
                    if(localIndex.HasValue)
                    {
                        destinationReceiver = ((ILocalGPIOReceiver)destination).GetLocalReceiver(localIndex.Value);
                    }
                    else
                    {
                        destinationReceiver = (IGPIOReceiver)destination;
                    }

                    var key = new IrqDestination(destinationReference.Value, localIndex, index);
                    if(irqCombiners.TryGetValue(key, out var combinerConnection))
                    {
                        // Connect the first one to the old destination
                        var combiner = combinerConnection.Combiner;
                        if(combinerConnection.NextConnectionIndex == 0)
                        {
                            combiner.OutputLine.Connect(destinationReceiver, index);
                        }
                        destinationReceiver = combiner;
                        index = combinerConnection.NextConnectionIndex++;
                    }

                    source.Connect(destinationReceiver, index);
                }
            }
        }

        private List<Entry> RegisterFromEntries(IEnumerable<Entry> sortedEntries)
        {
            var result = new List<Entry>();
            foreach(var entry in sortedEntries)
            {
                if(!TryRegisterFromEntry(entry))
                {
                    result.Add(entry);
                }
            }
            return result;
        }

        private bool AreAllParentsRegistered(Entry entry)
        {
            foreach(var registrationInfo in entry.RegistrationInfos)
            {
                if(registrationInfo.Register == null)
                {
                    return true;
                }
                var register = variableStore.GetVariableFromReference(registrationInfo.Register).Value;
                var registerAsPeripheral = register as IPeripheral;
                if(registerAsPeripheral == null)
                {
                    HandleError(ParsingError.CastException, registrationInfo.Register,
                                string.Format("Exception was thrown during registration of '{0}' in '{1}':{2}'{1}' does not implement IPeripheral.",
                                              entry.VariableName, registrationInfo.Register.Value, Environment.NewLine), false);
                }
                if(!machine.IsRegistered((IPeripheral)register))
                {
                    return false;
                }
            }
            return true;
        }

        private IReadOnlyDictionary<string, int> GetStateBits(string initiator)
        {
            if(!string.IsNullOrEmpty(initiator))
            {
                if(!variableStore.TryGetVariableInLocalScope(initiator, out var variable))
                {
                    throw new RecoverableException($"Invalid initiator: {initiator}");
                }
                return (variable.Value as IPeripheralWithTransactionState)?.StateBits;
            }

            return machine.SystemBus.GetCommonStateBits();
        }

        private bool TryRegisterFromEntry(Entry entry)
        {
            if(!AreAllParentsRegistered(entry))
            {
                return false;
            }
            foreach(var registrationInfo in entry.RegistrationInfos)
            {
                if(registrationInfo.Register == null)
                {
                    // registration canceling entry (i.e. @none)
                    // it may not coexist with other entries, so we return
                    return true;
                }
                var register = variableStore.GetVariableFromReference(registrationInfo.Register).Value;
                var registrationPoints = new List<IRegistrationPoint>();
                if(registrationInfo.Constructor != null)
                {
                    var constructorParameters = registrationInfo.Constructor.GetParameters();
                    var constructorParameterValues = new object[constructorParameters.Length];
                    int i;
                    if(registrationInfo.ConvertedValue == null)
                    {
                        i = 0;
                    }
                    else
                    {
                        constructorParameterValues[0] = registrationInfo.ConvertedValue;
                        i = 1;
                    }
                    for(; i < constructorParameters.Length; i++)
                    {
                        FillDefaultParameter(ref constructorParameterValues[i], constructorParameters[i]);
                    }
                    registrationPoints.Add((IRegistrationPoint)registrationInfo.Constructor.Invoke(constructorParameterValues));
                }
                else
                {
                    var referenceRegPoint = registrationInfo.RegistrationPoint as ReferenceValue;
                    var objectRegPoint = registrationInfo.RegistrationPoint as ObjectValue;
                    if(referenceRegPoint != null)
                    {
                        registrationPoints.Add((IRegistrationPoint)variableStore.GetVariableFromReference(referenceRegPoint).Value);
                    }
                    else if(objectRegPoint != null)
                    {
                        var registrationPoint = (IRegistrationPoint)CreateFromObjectValue(objectRegPoint);
                        if(registrationPoint is IConditionalRegistration cr && cr.Condition != null && !machine.IgnorePeripheralRegistrationConditions)
                        {
                            // Split it into simple registration points (one condition per) for each initiator
                            var condition = AccessConditionParser.ParseCondition(cr.Condition);
                            var conditionPerInitiator = AccessConditionParser.EvaluateWithStateBits(condition, GetStateBits);
                            foreach(var initiatorName in conditionPerInitiator.Keys)
                            {
                                IPeripheral initiator = null;
                                // The empty string is used as a placeholder initiator name, the conditions grouped under it
                                // should be global (that is have no initiator condition). The created conditional registrations
                                // will have Initiator == null.
                                if(!string.IsNullOrEmpty(initiatorName))
                                {
                                    initiator = variableStore.GetVariableInLocalScope(initiatorName).Value as IPeripheral;
                                    if(initiator == null)
                                    {
                                        throw new RecoverableException($"Initiator '{initiatorName}' is not a peripheral");
                                    }
                                }
                                foreach(var initiatorCond in conditionPerInitiator[initiatorName])
                                {
                                    registrationPoints.Add(cr.WithInitiatorAndStateMask(initiator, initiatorCond));
                                }
                            }
                        }
                        else
                        {
                            // If IgnorePeripheralRegistrationConditions is set, the point is added as-is, without
                            // transforming Condition into StateMask, so the condition is inert.
                            registrationPoints.Add(registrationPoint);
                        }
                        UpdatePropertiesAndInterruptsOnUpdateQueue();
                    }
                    else
                    {
                        // it might be that this is real NullRegistrationPoint
                        if(registrationInfo.RegistrationPoint != null)
                        {
                            HandleInternalError(registrationInfo.RegistrationPoint);
                        }
                        registrationPoints.Add(NullRegistrationPoint.Instance);
                    }
                }
                try
                {
                    foreach(var registrationPoint in registrationPoints)
                    {
                        registrationInfo.RegistrationInterface.GetMethod("Register").Invoke(register, new[] { entry.Variable.Value, registrationPoint });
                        // Remove this entry from the list of dangling disposables if it was registered. This has to be done before
                        // HandleError, so it is not disposed if for example registering at the second point throws.
                        if(entry.Variable.Value is IDisposable disposable)
                        {
                            createdDisposables.Remove(disposable);
                        }
                    }
                }
                catch(TargetInvocationException exception)
                {
                    // If this is a bus peripheral, its constructor might have called GetSystemBus(this), which leaves a
                    // reference to the peripheral even if it fails to get registered. Clean up this reference.
                    if(entry.Variable.Value is IBusPeripheral busPeripheral)
                    {
                        machine.TryRemoveBusController(busPeripheral);
                    }
                    var recoverableException = exception.InnerException as RecoverableException;
                    if(recoverableException == null)
                    {
                        throw;
                    }
                    HandleError(ParsingError.RegistrationException, registrationInfo.Register,
                                string.Format("Exception was thrown during registration of '{0}' in '{1}':{2}{3}",
                                              entry.VariableName, registrationInfo.Register.Value, Environment.NewLine, recoverableException.Message), false);
                }
            }
            try
            {
                machine.SetLocalName((IPeripheral)entry.Variable.Value, entry.Alias != null ? entry.Alias.Value : entry.VariableName);
            }
            catch(RecoverableException exception)
            {
                HandleError(ParsingError.NameSettingException, (IWithPosition)entry.Alias ?? entry.RegistrationInfos.First().Register,
                            string.Format("Exception was thrown during setting a name: {0}{1}", Environment.NewLine, exception.Message), false);
            }
            return true;
        }

        private void ValidateAttributePreMerge(Type objectType, Syntax.Attribute syntaxAttribute)
        {
            var ctorOrPropertyAttribute = syntaxAttribute as ConstructorOrPropertyAttribute;
            // at this point we can only fully validate properties, because only after merge we will know which ctor to choose
            if(ctorOrPropertyAttribute != null)
            {
                if(ctorOrPropertyAttribute.IsPropertyAttribute)
                {
                    var name = ctorOrPropertyAttribute.Name;
                    var propertyInfo = objectType.GetProperty(name);
                    if(propertyInfo != null)
                    {
                        ValidateProperty(propertyInfo, ctorOrPropertyAttribute);
                    }
                    else
                    {
                        HandleError(ParsingError.PropertyDoesNotExist, syntaxAttribute,
                                    string.Format("Property '{0}' does not exist in type '{1}.", ctorOrPropertyAttribute.Name, objectType), false);
                    }
                    ctorOrPropertyAttribute.Property = propertyInfo;
                    return;
                }

                // for ctor attributes we only check object values and whether reference exists
                var objectValue = ctorOrPropertyAttribute.Value as ObjectValue;
                var referenceValue = ctorOrPropertyAttribute.Value as ReferenceValue;
                if(referenceValue != null)
                {
                    // we only check whether this reference exists, its type cannot be checked at this point, therefore friendly name does not matter
                    ValidateReference("", new[] { typeof(object) }, referenceValue);
                }
                if(objectValue != null)
                {
                    ValidateObjectValue(string.Format("Constructor parameter {0}", ctorOrPropertyAttribute.Name), new[] { typeof(object) }, objectValue);
                }
            }

            var irqAttribute = syntaxAttribute as IrqAttribute;
            if(irqAttribute != null)
            {
                foreach(var attribute in irqAttribute.Destinations)
                {
                    Variable irqDestinationVariable;
                    if(attribute.DestinationPeripheral != null)
                    {
                        if(!variableStore.TryGetVariableFromReference(attribute.DestinationPeripheral.Reference, out irqDestinationVariable))
                        {
                            HandleError(ParsingError.IrqDestinationDoesNotExist, attribute.DestinationPeripheral,
                                        string.Format("Irq destination '{0}' does not exist.", attribute.DestinationPeripheral.Reference.Value), true);
                        }

                        if(attribute.DestinationPeripheral.LocalIndex.HasValue && !typeof(ILocalGPIOReceiver).IsAssignableFrom(irqDestinationVariable.VariableType))
                        {
                            HandleError(ParsingError.NotLocalGpioReceiver, attribute.DestinationPeripheral,
                                        string.Format("Used local irq destination, while type '{0}' does not implement ILocalGPIOReceiver.", irqDestinationVariable.VariableType), true);
                        }
                    }
                    else
                    {
                        // irq -> none case
                        irqDestinationVariable = null;
                    }

                    if(irqAttribute.Sources == null)
                    {
                        var gpioProperties = GetGpioProperties(objectType).ToArray();
                        if(gpioProperties.Length == 0)
                        {
                            HandleError(ParsingError.IrqSourceDoesNotExist, irqAttribute,
                                        string.Format("Type '{0}' does not contain any property of type GPIO.", objectType), false);
                        }
                        if(gpioProperties.Length > 1)
                        {
                            // If we get more than one property, try to further narrow the list - search if there is one with DefaultInterruptAttribute
                            gpioProperties = gpioProperties.Where(p => p.GetCustomAttribute(typeof(DefaultInterruptAttribute)) != null).ToArray();
                        }
                        // Now, there are the following possibilities:
                        // (1) either there is only one GPIO in the peripheral model
                        // (2) there are multiple GPIOs but one is marked with DefaultInterruptAttribute
                        // (3) there are multiple GPIOs but none is marked with DefaultInterruptAttribute
                        // (4) there are multiple GPIOs and several are marked with DefaultInterruptAttribute
                        // The clause below covers options (3) and (4) - it impossible to determine default interrupt here.
                        if(gpioProperties.Length != 1)
                        {
                            HandleError(ParsingError.AmbiguousDefaultIrqSource, irqAttribute,
                                        "Ambiguous choice of default interrupt." +
                                        $"\nThere are the following properties of GPIO type available: {Misc.PrettyPrintCollection(GetGpioProperties(objectType), e => e.Name)}.",
                                        false);
                        }
                        // we can now fill the missing source so that we can treat default irqs as normal ones from this point on
                        irqAttribute.SetDefaultSource(gpioProperties[0].Name);
                    }
                    else
                    {
                        if(attribute.Destinations != null)
                        {
                            // for irq -> none arity is always correct
                            var leftArity = irqAttribute.Sources.Sum(x => x.Ends.Count());
                            var rightArity = attribute.Destinations.Sum(x => x.Ends.Count());
                            if(leftArity != rightArity)
                            {
                                HandleError(ParsingError.WrongIrqArity, irqAttribute,
                                            string.Format("Irq arity does not match. It is {0} on the left side and {1} on the right side.", leftArity, rightArity), false);
                            }
                        }

                        foreach(var source in irqAttribute.Sources)
                        {
                            foreach(var end in source.Ends)
                            {
                                if(end.PropertyName != null)
                                {
                                    var gpioProperty = objectType.GetProperty(end.PropertyName);
                                    if(gpioProperty == null || gpioProperty.PropertyType != typeof(GPIO))
                                    {
                                        HandleError(ParsingError.IrqSourceDoesNotExist, source,
                                                    string.Format("Property '{0}' does not exist in '{1}' or is not of the GPIO type.", end.PropertyName, objectType), true);
                                    }
                                }
                                else
                                {
                                    if(!typeof(INumberedGPIOOutput).IsAssignableFrom(objectType))
                                    {
                                        HandleError(ParsingError.IrqSourceIsNotNumberedGpioOutput, source,
                                                    string.Format("Type '{0}' is not a numbered gpio output, while numbered output was used.", objectType), true);
                                    }
                                }
                            }
                        }
                    }

                    if(irqDestinationVariable != null &&
                        !(typeof(IGPIOReceiver).IsAssignableFrom(irqDestinationVariable.VariableType) || typeof(ILocalGPIOReceiver).IsAssignableFrom(irqDestinationVariable.VariableType)))
                    {
                        HandleError(ParsingError.IrqDestinationIsNotIrqReceiver, attribute.DestinationPeripheral,
                                    string.Format("Type '{0}' does not implement IGPIOReceiver or ILocalGPIOReceiver and cannot be a destination of interrupts.", irqDestinationVariable.VariableType), false);
                    }
                    return;
                }
            }
        }

        private void ValidateProperty(PropertyInfo propertyInfo, ConstructorOrPropertyAttribute attribute)
        {
            var value = attribute.Value;
            var propertyType = propertyInfo.PropertyType;

            if(propertyInfo.GetSetMethod() == null)
            {
                HandleError(ParsingError.PropertyNotWritable, attribute, string.Format("Property {0} does not have a public setter.", propertyInfo.Name), false);
            }

            var propertyFriendlyName = string.Format("Property '{0}'", attribute.Name);
            // verification:
            // - X: none attributes (none values) are not checked
            // - simple values are simply converted
            // - references are type checked
            // - inline objects are recursively type checked
            if(attribute.Value == null)
            {
                return;
            }
            var referenceValue = attribute.Value as ReferenceValue;
            var objectValue = attribute.Value as ObjectValue;
            if(referenceValue != null)
            {
                ValidateReference(propertyFriendlyName, new[] { propertyInfo.PropertyType }, referenceValue);
            }
            else if(objectValue != null)
            {
                ValidateObjectValue(propertyFriendlyName, new[] { propertyInfo.PropertyType }, objectValue);
            }
            else
            {
                ConvertFromValue(propertyInfo.PropertyType, attribute.Value);
            }
        }

        private IEnumerable<Type> ValidateReference(string friendlyName, Type[] typesToAssign, ReferenceValue value)
        {
            Variable referenceVariable;
            if(!variableStore.TryGetVariableFromReference(value, out referenceVariable))
            {
                HandleError(ParsingError.MissingReference, value, string.Format("Undefined reference '{0}'.", value.Value), true);
            }

            var result = typesToAssign.Where(x => x.IsAssignableFrom(referenceVariable.VariableType));
            if(!result.Any())
            {
                string typeListing = GetTypeListing(typesToAssign);
                HandleError(ParsingError.TypeMismatch, value,
                            string.Format("{0} of {3} is not assignable from reference '{1}' of type '{2}'.",
                                          friendlyName, value.Value, referenceVariable.VariableType, typeListing), true);
            }
            return result;
        }

        private IEnumerable<Type> ValidateObjectValue(string friendlyName, Type[] typesToAssign, ObjectValue value)
        {
            var objectValueType = ResolveTypeOrThrow(value.TypeName, value);
            value.ObjectValueType = objectValueType;
            var result = typesToAssign.Where(x => x.IsAssignableFrom(objectValueType));
            if(!result.Any())
            {
                var typeListing = GetTypeListing(typesToAssign);
                HandleError(ParsingError.TypeMismatch, value,
                            string.Format("{0} of {1} is not assignable from object of type '{2}'.", friendlyName, typeListing, objectValueType), false);
            }
            foreach(var attribute in value.Attributes)
            {
                ValidateAttributePreMerge(objectValueType, attribute);
            }
            if(value.Attributes.Any(x => x is InitAttribute))
            {
                ValidateInitSection(value);
            }
            return result;
        }

        private void CheckRepeatedCtorAttributes(IEnumerable<ConstructorOrPropertyAttribute> attributes)
        {
            var names = new HashSet<string>();
            foreach(var attribute in attributes)
            {
                if(!names.Add(attribute.Name))
                {
                    HandleError(ParsingError.PropertyOrCtorNameUsedMoreThanOnce, attribute,
                                string.Format("{1} '{0}' is used more than once.", attribute.Name, attribute.IsPropertyAttribute ? "Property" : "Constructor argument"), false);
                }
            }
        }

        private void CheckOverlappingIrqs(IEnumerable<IrqAttribute> attributes)
        {
            var sources = new HashSet<IrqEnd>();
            foreach(var attribute in attributes)
            {
                foreach(var source in attribute.Sources)
                {
                    foreach(var end in source.Ends)
                    {
                        if(!sources.Add(end))
                        {
                            // source position information can only be obtained if this is not a default irq source
                            // if it is - we use the whole attribute
                            HandleError(ParsingError.IrqSourceUsedMoreThanOnce, source.StartPosition != null ? (IWithPosition)source : attribute,
                                        string.Format("Interrupt '{0}' has already been used as a source in this entry.", end.ToShortString()), true);
                        }
                    }
                }
            }
        }

        private void CheckRepeatedInitAttributes(IEnumerable<InitAttribute> attributes)
        {
            var secondInitAttribute = attributes.Skip(1).FirstOrDefault();
            if(secondInitAttribute != null)
            {
                HandleError(ParsingError.MoreThanOneInitAttribute, secondInitAttribute, "Entry can contain only one init attribute.", false);
            }
        }

        private void CheckRepeatedResetAttributes(IEnumerable<ResetAttribute> attributes)
        {
            var secondResetAttribute = attributes.Skip(1).FirstOrDefault();
            if(secondResetAttribute != null)
            {
                HandleError(ParsingError.MoreThanOneResetAttribute, secondResetAttribute, "Entry can contain only one reset attribute.", false);
            }
        }

        private ConversionResult TryConvertSimplestValue<T>(Value value, Type expectedType, Type comparedType, ref object result) where T : Value, ISimplestValue
        {
            var tValue = value as T;
            if(tValue == null)
            {
                return ConversionResult.ConversionNotApplied;
            }
            if(comparedType != expectedType)
            {
                return new ConversionResult(ConversionResultType.ConversionUnsuccesful, ParsingError.TypeMismatch, string.Format(TypeMismatchMessage, expectedType));
            }
            result = tValue.ConvertedValue;
            return ConversionResult.Success;
        }

        private ConversionResult TryConvertRangeValue(Value value, Type expectedType, ref object result)
        {
            if(value == null && expectedType == typeof(Range?))
            {
                result = (Range?)null;
                return ConversionResult.Success;
            }

            var tValue = value as RangeValue;
            if(tValue == null)
            {
                return ConversionResult.ConversionNotApplied;
            }

            if(expectedType == typeof(Range?))
            {
                result = (Range?)tValue.ConvertedValue;
                return ConversionResult.Success;
            }
            else if(expectedType == typeof(Range))
            {
                result = tValue.ConvertedValue;
                return ConversionResult.Success;
            }

            return new ConversionResult(ConversionResultType.ConversionUnsuccesful, ParsingError.TypeMismatch, string.Format(TypeMismatchMessage, expectedType));
        }

        private ConversionResult TryConvertListValue(Value value, Type expectedType, ref object result)
        {
            if(!(value is ListValue listValue))
            {
                return ConversionResult.ConversionNotApplied;
            }
            var elementType = expectedType.GetEnumerableElementType();
            if(elementType == null || !(typeof(IList).IsAssignableFrom(expectedType) || expectedType.IsArray))
            {
                var enumerableType = typeof(IEnumerable<>).MakeGenericType(elementType);
                return new ConversionResult(ConversionResultType.ConversionUnsuccesful, ParsingError.TypeMismatch, string.Format(TypeMismatchMessage, enumerableType));
            }

            var items = (IList)Activator.CreateInstance(typeof(List<>).MakeGenericType(elementType));
            foreach(var item in listValue.Items)
            {
                items.Add(ConvertFromValue(elementType, item));
            }

            if(expectedType.IsArray)
            {
                var array = Array.CreateInstance(elementType, items.Count);
                items.CopyTo(array, 0);
                result = array;
            }
            else
            {
                result = items;
            }
            return ConversionResult.Success;
        }

        private ConversionResult TryConvertSimpleValue(Type expectedType, Value value, out object result, bool silent = false)
        {
            result = null;
            expectedType = Nullable.GetUnderlyingType(expectedType) ?? expectedType;

            if(value is EmptyValue)
            {
                result = expectedType.IsValueType ? Activator.CreateInstance(expectedType) : null;
                return ConversionResult.Success;
            }

            var numericalValue = value as NumericalValue;
            var enumValue = value as EnumValue;

            var results = new[]
            {
                TryConvertSimplestValue<StringValue>(value, expectedType, typeof(string), ref result),
                TryConvertSimplestValue<BoolValue>(value, expectedType, typeof(bool), ref result),
                TryConvertRangeValue(value, expectedType, ref result),
                TryConvertListValue(value, expectedType, ref result),
            };

            var meaningfulResult = results.FirstOrDefault(x => x.ResultType != ConversionResultType.ConversionNotApplied);
            if(meaningfulResult != null)
            {
                return meaningfulResult;
            }

            if(numericalValue != null)
            {
                // numbers can be interpreted as enums either when they match a numerical value of one
                // of the enum's entries or when the enum has AllowAnyNumericalValueAttribute defined
                if(expectedType.IsEnum && SmartParser.Instance.TryParse(numericalValue.Value, expectedType, out result))
                {
                    return ConversionResult.Success;
                }
                if(!NumericTypes.Contains(expectedType) || !SmartParser.Instance.TryParse(numericalValue.Value, expectedType, out result))
                {
                    return new ConversionResult(ConversionResultType.ConversionUnsuccesful, ParsingError.TypeMismatch, string.Format(TypeMismatchMessage, expectedType));
                }
                return ConversionResult.Success;
            }

            if(enumValue != null)
            {
                if(!expectedType.IsEnum)
                {
                    return new ConversionResult(ConversionResultType.ConversionUnsuccesful, ParsingError.TypeMismatch, string.Format(TypeMismatchMessage, expectedType));
                }

                // If the enum was specified in full (and not as just .Value) then verify whether
                // the given namespace and type name matches
                if(enumValue.IsFullyQualified)
                {
                    // Compare types first as enum's type may use an alias
                    if(!TypeNameMatches(enumValue.TypeName, expectedType, silent))
                    {
                        return new ConversionResult(ConversionResultType.ConversionUnsuccesful, ParsingError.EnumMismatch,
                                                    $"Enum type mismatch, expected '{expectedType.Name}' instead of '{enumValue.TypeName}'.");
                    }

                    var expectedNamespace = expectedType.Namespace.Split('.');
                    var givenNamespace = enumValue.ReversedNamespace;

                    // Compare namespaces
                    foreach(var names in givenNamespace.Zip(expectedNamespace.Reverse(), (first, second) => Tuple.Create(first, second)))
                    {
                        if(names.Item1 != names.Item2)
                        {
                            return new ConversionResult(ConversionResultType.ConversionUnsuccesful, ParsingError.EnumMismatch,
                                                        $"Enum namespace mismatch, expected '{names.Item2}' instead of '{names.Item1}'.");
                        }
                    }
                }

                if(!SmartParser.Instance.TryParse(enumValue.Value, expectedType, out result))
                {
                    return new ConversionResult(ConversionResultType.ConversionUnsuccesful, ParsingError.EnumMismatch,
                                                $"Unexpected enum value '{enumValue.Value}'.{Environment.NewLine}{Environment.NewLine}    Valid values:{Environment.NewLine}{GetValidEnumValues(expectedType)}");
                }
                return ConversionResult.Success;
            }

            return ConversionResult.ConversionNotApplied;
        }

        private object ConvertFromValue(Type expectedType, Value value)
        {
            object result;
            var simpleConversionResult = TryConvertSimpleValue(expectedType, value, out result);
            if(simpleConversionResult.ResultType == ConversionResultType.ConversionSuccessful)
            {
                return result;
            }
            if(simpleConversionResult.ResultType == ConversionResultType.ConversionUnsuccesful)
            {
                HandleError(simpleConversionResult.Error, value, simpleConversionResult.Message, true);
            }

            var objectValue = value as ObjectValue;
            if(objectValue != null)
            {
                return CreateFromObjectValue(objectValue);
            }

            var referenceValue = value as ReferenceValue;
            if(referenceValue != null)
            {
                return variableStore.GetVariableFromReference(referenceValue).Value;
            }

            HandleInternalError(value); // should not reach here
            return null;
        }

        private ConstructorInfo FindConstructor(Type type, IEnumerable<ConstructorOrPropertyAttribute> attributes, IWithPosition responsibleObject)
        {
            var constructorSelectionReport = new LazyList<string>();
            var result = new List<ConstructorInfo>();
            var availableCtors = type.GetConstructors();
            // here we group attributes into two elements of a dictionary: keyed true, having a value and keyed false, having being of a "x: none" form
            var attributeGroups = attributes.GroupBy(x => x.Value != null).ToDictionary(x => x.Key, x => (IEnumerable<ConstructorOrPropertyAttribute>)x);
            // we can simply treat x: none entries as non existiting (they are only important during merge phase)
            attributes = attributeGroups.ContainsKey(true) ? attributeGroups[true] : new ConstructorOrPropertyAttribute[0];
            attributes = attributes.ToArray();

            if(attributeGroups.ContainsKey(false))
            {
                constructorSelectionReport.Add(() => "Following attributes were set to none (and therefore ignored):");
                foreach(var attribute in attributeGroups[false])
                {
                    constructorSelectionReport.Add(() => string.Format("  '{0}' at {1}", attribute.Name, GetFormattedPosition(attribute)));
                }
            }

            foreach(var ctor in availableCtors)
            {
                constructorSelectionReport.Add(() => "");
                constructorSelectionReport.Add(() => string.Format("Considering ctor {0}.", GetFriendlyConstructorName(ctor)));
                var unusedAttributes = new HashSet<ConstructorOrPropertyAttribute>(attributes);

                foreach(var argument in ctor.GetParameters())
                {
                    var correspondingAttributes = attributes.Where(x => ParameterNameMatches(x.Name, argument));
                    if(correspondingAttributes.Count() > 1)
                    {
                        HandleError(ParsingError.AliasedAndNormalArgumentName, responsibleObject,
                                    "Ambiguous choice between aliased and normal argument name:" + Environment.NewLine +
                                    String.Join(Environment.NewLine, correspondingAttributes.Select(x => x.Name + ": " + x.Value)), true);
                    }
                    var correspondingAttribute = correspondingAttributes.FirstOrDefault();
                    if(correspondingAttribute == null)
                    {
                        object defaultValue = null;
                        // let's check if we can fill this argument with default value
                        if(!argument.HasDefaultValue && !TryGetValueOfOurDefaultParameter(argument.ParameterType, out defaultValue))
                        {
                            constructorSelectionReport.Add(() => string.Format("  Could not find corresponding attribute for parameter '{0}' of type '{1}' and it is not a default parameter. Rejecting constructor.",
                                                                   argument.Name, argument.ParameterType));
                            goto next;
                        }
                        if(defaultValue == null)
                        {
                            defaultValue = argument.DefaultValue;
                        }
                        constructorSelectionReport.Add(() => string.Format("  Parameter '{0}' of type '{1}' filled with default value = '{2}'.", argument.Name, argument.ParameterType, defaultValue));
                        continue;
                    }
                    if(typeof(IMachine).IsAssignableFrom(argument.ParameterType))
                    {
                        constructorSelectionReport.Add(() => $"  Value provided for parameter {argument.Name} is of internal Machine type and it cannot be assigned by user. Rejecting contructor.");
                        goto next;
                    }
                    constructorSelectionReport.Add(() => string.Format("  For parameter '{0}' of type '{1}' found attribute at {3} with value {2}",
                                                           argument.Name, argument.ParameterType, correspondingAttribute.Value, GetFormattedPosition(correspondingAttribute)));
                    object convertedObject;
                    var simpleConversionResult = TryConvertSimpleValue(argument.ParameterType, correspondingAttribute.Value, out convertedObject);
                    if(simpleConversionResult.ResultType == ConversionResultType.ConversionUnsuccesful)
                    {
                        constructorSelectionReport.Add(() => "    There was an error when converting the value:");
                        constructorSelectionReport.Add(() => "    " + simpleConversionResult.Message);
                        goto next; // same as above
                    }
                    if(simpleConversionResult.ResultType == ConversionResultType.ConversionSuccessful)
                    {
                        constructorSelectionReport.Add(() => string.Format("    Value converted succesfully, it is = '{0}'", convertedObject));
                        unusedAttributes.Remove(correspondingAttribute);
                        continue;
                    }
                    var referenceValue = correspondingAttribute.Value as ReferenceValue;
                    if(referenceValue != null)
                    {
                        if(argument.ParameterType.IsAssignableFrom(variableStore.GetVariableFromReference(referenceValue).VariableType))
                        {
                            constructorSelectionReport.Add(() => "    Parameter is assignable from the reference value.");
                            unusedAttributes.Remove(correspondingAttribute);
                            continue;
                        }
                        else
                        {
                            constructorSelectionReport.Add(() => "    Parameter is not assignable from the reference value, constructor rejected.");
                            goto next;
                        }
                    }
                    var objectValue = correspondingAttribute.Value as ObjectValue;
                    if(objectValue != null)
                    {
                        if(argument.ParameterType.IsAssignableFrom(objectValue.ObjectValueType))
                        {
                            constructorSelectionReport.Add(() => "    Parameter is assignable from the object value.");
                            unusedAttributes.Remove(correspondingAttribute);
                            continue;
                        }
                        else
                        {
                            constructorSelectionReport.Add(() => "    Parameter is not assignable from the object value, constructor rejected.");
                            goto next;
                        }
                    }
                }

                if(unusedAttributes.Count == 0)
                {
                    constructorSelectionReport.Add(() => "  No unused attributes, constructor accepted.");
                    result.Add(ctor);
                }
                else
                {
                    constructorSelectionReport.Add(() => string.Format("  Constructor rejected, {0} unused attributes left:", unusedAttributes.Count));
                    foreach(var attribute in unusedAttributes)
                    {
                        constructorSelectionReport.Add(() => string.Format("    '{0}' with value '{1}' at {2}", attribute.Name, attribute.Value, GetFormattedPosition(attribute)));
                    }
                }
            next:;
            }

            if(result.Count == 1)
            {
                return result[0];
            }

            var constructorSelectionReportAsString = $"{Environment.NewLine}Constructor selection report:{Environment.NewLine}{string.Join(Environment.NewLine, constructorSelectionReport.ToList())}";

            if(result.Count == 0)
            {
                HandleError(ParsingError.NoCtor, responsibleObject,
                            string.Format("Could not find suitable constructor for type '{0}'.{1}", type, constructorSelectionReportAsString), false);
            }
            else
            {
                var prettyPrintedCtors = result.Select(x => x.GetParameters().Select(y => y.Name + ": " + y.ParameterType).Aggregate((y, z) => y + ", " + z))
                                               .Select(x => string.Format("({0})", x)).Aggregate((x, y) => x + Environment.NewLine + y);
                HandleError(ParsingError.AmbiguousCtor, responsibleObject,
                            string.Format("Ambiguous choice between constructors for type '{0}':{1}{2}{3}", type, Environment.NewLine, prettyPrintedCtors, constructorSelectionReportAsString), false);
            }

            HandleInternalError();
            return result[0]; // will not reach here
        }

        private bool TryGetValueOfOurDefaultParameter(Type type, out object value)
        {
            value = null;
            if(typeof(IMachine).IsAssignableFrom(type))
            {
                value = machine;
                return true;
            }
            return false;
        }

        private bool ParameterNameMatches(string given, ParameterInfo info, bool silent = false)
        {
            return NameOrAliasMatches(given, info.Name, "parameter", info.GetCustomAttribute<NameAliasAttribute>(), silent);
        }

        private bool TypeNameMatches(string given, Type type, bool silent = false)
        {
            return NameOrAliasMatches(given, type.Name, "type", type.GetCustomAttribute<NameAliasAttribute>(), silent);
        }

        private bool NameOrAliasMatches(string given, string name, string typeClass, NameAliasAttribute alias, bool silent = false)
        {
            if(given == name)
            {
                return true;
            }

            if(alias != null && alias.Name == given)
            {
                if(!silent && alias.WarnOnUsage)
                {
                    Logger.Log(LogLevel.Warning, "Using alias '{0}' for {1} '{2}'", alias.Name, typeClass, name);
                }

                return true;
            }

            return false;
        }

        private void HandleInternalError(IWithPosition failingObject = null,
            [CallerMemberName] string callingMethod = "",
            [CallerFilePath] string callingFilePath = "",
            [CallerLineNumber] int callingFileLineNumber = 0)
        {
            var message = string.Format("Internal error during processing in function '{0}' at {1}:{2}.", callingMethod, callingFilePath, callingFileLineNumber);
            if(failingObject != null)
            {
                HandleError(ParsingError.InternalError, failingObject, message, false);
            }
            else
            {
                throw new ParsingException(ParsingError.InternalError, message);
            }
        }

        private void HandleError(ParsingError error, IWithPosition failingObject, string message, bool longMark)
        {
            for(int i = createdDisposables.Count - 1; i >= 0; --i)
            {
                createdDisposables[i].Dispose();
            }
            createdDisposables.Clear();

            // Ignoring failure as the location is optional here. It won't be present when calling
            // Monitor.Parse directly (as in unit tests for example) and we don't want to lose the
            // actual error by overwriting it with an error that no location was found.
            GetElementSourceAndPath(failingObject, out var fileName, out var source);

            var lineNumber = failingObject.StartPosition.Line;
            var columnNumber = failingObject.StartPosition.Column;
            var messageBuilder = new StringBuilder();
            messageBuilder.AppendFormat("Error E{0:D2}: ", (int)error);
            messageBuilder.AppendLine(message);
            messageBuilder.AppendFormat("At {2}{0}:{1}:", lineNumber, columnNumber, string.IsNullOrEmpty(fileName) ? "" : fileName + ':');
            messageBuilder.AppendLine();
            if(source != null)
            {
                var sourceInLines = source.Replace("\r", string.Empty).Split(new[] { '\n' }, StringSplitOptions.None);
                var problematicLine = sourceInLines[lineNumber - 1];
                messageBuilder.AppendLine(problematicLine);
                messageBuilder.Append(' ', columnNumber - 1);
                messageBuilder.Append('^', longMark ? Math.Min(problematicLine.Length - (columnNumber - 1), failingObject.Length) : 1);
            }
            throw new ParsingException(error, messageBuilder.ToString());
        }

        private Type ResolveTypeOrThrow(string typeName, IWithPosition syntaxElement)
        {
            var extendedTypeName = typeName.StartsWith(DefaultNamespace, StringComparison.Ordinal) ? typeName : DefaultNamespace + typeName;

            var manager = TypeManager.Instance;
            var result = manager.TryGetTypeByName(typeName) ?? manager.TryGetTypeByName(extendedTypeName);
            if(result == null)
            {
                HandleError(ParsingError.TypeNotResolved, syntaxElement, string.Format("Could not resolve type: '{0}'.", typeName), true);
            }
            return result;
        }

        private string GetFormattedPosition(IWithPosition element)
        {
            string path, unused;
            if(!GetElementSourceAndPath(element, out path, out unused))
            {
                HandleInternalError();
            }
            return string.Format("{2}{0}:{1}", element.StartPosition.Line, element.StartPosition.Column, path == "" ? "" : path + ':');
        }

        private bool GetElementSourceAndPath(IWithPosition element, out string file, out string source)
        {
            var syntaxErrorPosition = element as WithPositionForSyntaxErrors;
            if(syntaxErrorPosition != null)
            {
                file = syntaxErrorPosition.FileName;
                source = syntaxErrorPosition.Source;
                return true;
            }

            foreach(var description in processedDescriptions)
            {
                if(SyntaxTreeHelpers.ScanFor(description, element))
                {
                    file = description.FileName;
                    source = description.Source;
                    return true;
                }
            }
            source = null;
            file = null;
            return false;
        }

        private readonly Machine machine;
        private readonly IUsingResolver usingResolver;
        private readonly IScriptHandler scriptHandler;
        private readonly VariableStore variableStore;
        private readonly List<Description> processedDescriptions;
        private readonly Queue<ObjectValue> objectValueUpdateQueue;
        private readonly Queue<ObjectValue> objectValueInitQueue;
        private readonly Stack<string> usingsBeingProcessed;
        private readonly Dictionary<IrqDestination, IrqCombinerConnection> irqCombiners;
        private readonly List<IDisposable> createdDisposables;

        private static readonly HashSet<Type> NumericTypes = new HashSet<Type>(new []
        {
            typeof(sbyte), typeof(byte), typeof(short), typeof(ushort),
            typeof(int), typeof(uint), typeof(long), typeof(ulong),
            typeof(decimal), typeof(float), typeof(double)
        }.Select(x => new[] { x, typeof(Nullable<>).MakeGenericType(x)}).SelectMany(x => x));

        private const string DefaultNamespace = "Antmicro.Renode.Peripherals.";
        private const string TypeMismatchMessage = "Type mismatch. Expected {0}.";

        private class IrqCombinerConnection
        {
            public IrqCombinerConnection(CombinedInput combiner)
            {
                Combiner = combiner;
                NextConnectionIndex = 0;
            }

            public int NextConnectionIndex;

            public readonly CombinedInput Combiner;
        }

        private class WithPositionForSyntaxErrors : IWithPosition
        {
            public static WithPositionForSyntaxErrors FromResult<T>(IResult<T> result, string fileName, string source)
            {
                var position = new Position(result.Remainder.Position, result.Remainder.Line, result.Remainder.Column);
                return new WithPositionForSyntaxErrors(1, position, fileName, source);
            }

            public int Length { get; private set; }

            public Position StartPosition { get; private set; }

            public string FileName { get; private set; }

            public string Source { get; private set; }

            private WithPositionForSyntaxErrors(int length, Position startPosition, string fileName, string source)
            {
                Length = length;
                StartPosition = startPosition;
                FileName = fileName;
                Source = source;
            }
        }

        private class ReferenceValueStack
        {
            public ReferenceValueStack(ReferenceValueStack previous, ReferenceValue value, Entry entry)
            {
                Previous = previous;
                Value = value;
                Entry = entry;
            }

            public ReferenceValueStack Previous { get; private set; }

            public ReferenceValue Value { get; private set; }

            public Entry Entry { get; private set; }
        }

        private struct IrqDestination
        {
            public IrqDestination(string peripheralName, int? localIndex, int index)
            {
                PeripheralName = peripheralName;
                LocalIndex = localIndex;
                Index = index;
            }

            public readonly string PeripheralName;
            public readonly int? LocalIndex;
            public readonly int Index;
        }
    }
}