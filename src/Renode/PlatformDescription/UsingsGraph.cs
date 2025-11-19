//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System.Collections.Generic;
using System.IO;
using System.Linq;

using Antmicro.Renode.PlatformDescription.Syntax;

namespace Antmicro.Renode.PlatformDescription
{
    partial class CreationDriver
    {
        private class UsingsGraph
        {
            public UsingsGraph(CreationDriver creationDriver, string rootFilePath, string rootFileSource)
            {
                this.rootFilePath = rootFilePath;
                this.rootFileSource = rootFileSource;
                this.creationDriver = creationDriver;
                usingsMap = new Dictionary<string, GraphNode>();
            }

            public void TraverseDepthFirst(UsingsFileVisitor visitor)
            {
                // This function does a depth first search on the usings graph (with GraphNode nodes) and runs visitor
                // on each using file.
                var nodesToProcess = new Stack<GraphNode>();

                var graphNodeFinished = new Dictionary<GraphNode, bool>();
                var fileCurrentlyProcessed = new Dictionary<string, bool>();

                GraphNode rootNode = GetOrCreateGraphNode(creationDriver, rootFilePath, rootFileSource, "", null);
                fileCurrentlyProcessed[rootNode.FileId] = true;
                graphNodeFinished[rootNode] = false;

                nodesToProcess.Push(rootNode);
                while(nodesToProcess.Count != 0)
                {
                    var currentFile = nodesToProcess.Peek();

                    var finished = true;

                    // Iteration is in reverse to process the children in the same order as they are written in the platform
                    // description - usings later in the description are pushed to the stack first, so they are popped last.
                    foreach(var usingEntry in currentFile.ParsedDescription.Usings.Reverse())
                    {
                        var resolver = creationDriver.usingResolver.Resolve(usingEntry.Path, currentFile.Path);

                        if(resolver == null)
                        {
                            creationDriver.HandleError(ParsingError.UsingFileNotFound, usingEntry.Path,
                                    string.Format("Using '{0}' does not exist.", usingEntry.Path), true);
                        }

                        var filePath = Path.GetFullPath(resolver);

                        if(!File.Exists(filePath))
                        {
                            creationDriver.HandleError(ParsingError.UsingFileNotFound, usingEntry.Path,
                                    string.Format("Using '{0}' resolved as '{1}' does not exist.", usingEntry.Path, filePath), true);
                        }

                        var prefix = currentFile.Prefix + usingEntry.Prefix;
                        GraphNode node = GetOrCreateGraphNode(creationDriver, filePath, "", prefix, currentFile);

                        if(!graphNodeFinished.ContainsKey(node))
                        {
                            graphNodeFinished[node] = false;
                        }

                        if(!fileCurrentlyProcessed.ContainsKey(node.FileId))
                        {
                            fileCurrentlyProcessed[node.FileId] = false;
                        }

                        // Detect cycles.
                        if(fileCurrentlyProcessed[node.FileId] || node.Path == currentFile.Path)
                        {
                            creationDriver.HandleError(ParsingError.RecurringUsing, usingEntry,
                                        string.Format("There is a cycle in using file dependency."),
                                        false);
                        }

                        if(graphNodeFinished[node])
                        {
                            continue;
                        }

                        fileCurrentlyProcessed[node.FileId] = true;
                        nodesToProcess.Push(node);
                        finished = false;
                    }

                    if(finished)
                    {
                        visitor(currentFile.ParsedDescription, currentFile.Prefix);
                        graphNodeFinished[currentFile] = true;
                        currentFile = nodesToProcess.Pop();
                        fileCurrentlyProcessed[currentFile.FileId] = false;
                    }
                }
            }

            private GraphNode GetOrCreateGraphNode(CreationDriver creationDriver, string filePath, string source, string prefix, GraphNode parent)
            {
                if(!usingsMap.TryGetValue(GraphNode.MakeGraphId(parent?.GraphId ?? "", prefix, filePath), out var node))
                {
                    node = CreateGraphNode(creationDriver, filePath, source, prefix, parent);
                }
                return node;
            }

            private GraphNode CreateGraphNode(CreationDriver creationDriver, string filePath, string source, string prefix, GraphNode parent)
            {
                if(source == "")
                {
                    source = File.ReadAllText(filePath);
                }
                var description = creationDriver.ParseDescription(source, filePath);

                // processedDescriptions must be populated as soon as possible for HandleError to properly report error
                // locations.
                if(!creationDriver.processedDescriptions.Contains(description))
                {
                    creationDriver.processedDescriptions.Add(description);
                }

                ValidateDescriptionUsings(description);
                var node = new GraphNode(filePath, source, prefix, description, parent);
                usingsMap[node.GraphId] = node;
                return node;
            }

            private void ValidateDescriptionUsings(Description description)
            {
                var used = new HashSet<string>();
                foreach(var usingEntry in description.Usings)
                {
                    if(!used.Add(usingEntry.Prefix + usingEntry.Path))
                    {
                        creationDriver.HandleError(ParsingError.DuplicateUsing, usingEntry, "Duplicate using entry.", false);
                    }
                }
            }

            private readonly CreationDriver creationDriver;
            private readonly string rootFilePath;
            private readonly string rootFileSource;
            private readonly Dictionary<string, GraphNode> usingsMap;

            public delegate void UsingsFileVisitor(Description description, string prefix);

            private class GraphNode
            {
                public static string MakeGraphId(string parentGraphId, string prefix, string path)
                {
                    // Path can be empty, as is the case when loading a platform description from string.
                    // This is not a problem and doesn't require special handling, since there is at most one using like
                    // that in the usings hierarchy (the root).
                    return parentGraphId + prefix + path;
                }

                public GraphNode(string path, string source, string prefix, Description parsedDescription, GraphNode parent)
                {
                    Path = path;
                    Source = source;
                    Prefix = prefix;
                    Parent = parent;
                    GraphId = MakeGraphId(parent?.GraphId ?? "", prefix, path);
                    FileId = prefix + path;
                    ParsedDescription = parsedDescription;
                    SetupScopeInDescription(ParsedDescription, Prefix);
                }

                public string GraphId { get; }

                public string FileId { get; }

                public string Path { get; }

                public string Source { get; }

                public string Prefix { get; }

                public Description ParsedDescription { get; }

                public GraphNode Parent { get; set; }

                private void SetupScopeInDescription(Description description, string prefix)
                {
                    // This prefixes all variables with an appropriate prefix and sets the correct scope for the Description.
                    SyntaxTreeHelpers.VisitSyntaxTree<IPrefixable>(description, x => x.Prefix(prefix));
                    SyntaxTreeHelpers.VisitSyntaxTree<ReferenceValue>(description, x => x.Scope = description.FileName);
                }
            };
        }
    }
}