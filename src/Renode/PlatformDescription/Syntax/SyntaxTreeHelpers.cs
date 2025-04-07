//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;

namespace Antmicro.Renode.PlatformDescription.Syntax
{
    public static class SyntaxTreeHelpers
    {
        public static bool ScanFor(object objectToScan, IWithPosition objectToFind)
        {
            var found = false;
            VisitSyntaxTree<IWithPosition>(objectToScan, x =>
            {
                found |= objectToFind.Equals(x);
            });
            return found;
        }

        public static void VisitSyntaxTree<TValue>(object root, Action<TValue> visitorAction) where TValue : class
        {
            VisitSyntaxTreeInner<TValue>(root, visitorAction, null);
        }

        public static void VisitSyntaxTree<TValue>(object root, Action<TValue> visitorAction, Func<object, bool, bool> filter) where TValue : class
        {
            VisitSyntaxTreeInner(root, visitorAction, filter);
        }

        private static void VisitSyntaxTreeInner<TValue>(object objectToVisit, Action<TValue> visitorAction, Func<object, bool, bool> filter) where TValue : class
        {
            var objectAsValue = objectToVisit as TValue;
            if(objectAsValue != null)
            {
                visitorAction(objectAsValue);
            }

            var objectIsEntry = objectToVisit.GetType() == typeof(Antmicro.Renode.PlatformDescription.Syntax.Entry);

            var objectAsVisitable = objectToVisit as IVisitable;
            if(objectAsVisitable != null)
            {
                foreach(var element in objectAsVisitable.Visit())
                {
                    if(element != null && ApplyFilter(element, objectIsEntry, filter))
                    {
                        VisitSyntaxTreeInner(element, visitorAction, filter);
                    }
                }
                return;
            }

            var objectType = objectToVisit.GetType();
            var publicProperties = objectType.GetProperties();
            foreach(var property in publicProperties.Where(x => x.CanRead))
            {
                var propertyValue = property.GetGetMethod().Invoke(objectToVisit, new object[0]);
                if(propertyValue != null)
                {
                    var typeOfValue = propertyValue.GetType();
                    if(typeOfValue.GetInterfaces().Any(x => x.IsGenericType && x.GetGenericTypeDefinition() == typeof(IEnumerable<>) &&
                                                       x.GetGenericArguments()[0].Namespace.StartsWith(OurNamespace, StringComparison.InvariantCulture)))
                    {
                        foreach(var element in ((System.Collections.IEnumerable)propertyValue))
                        {
                            if(ApplyFilter(element, objectIsEntry, filter))
                            {
                                VisitSyntaxTreeInner(element, visitorAction, filter);
                            }
                        }
                    }
                    else if(typeOfValue.Namespace.StartsWith(OurNamespace, StringComparison.InvariantCulture))
                    {
                        if(ApplyFilter(propertyValue, objectIsEntry, filter))
                        {
                            VisitSyntaxTreeInner(propertyValue, visitorAction, filter);
                        }
                    }
                }
            }
        }

        private static bool ApplyFilter(object obj, bool isEntryChild, Func<object, bool, bool> filter)
        {
            return filter == null ? true : filter(obj, isEntryChild);
        }

        private static readonly string OurNamespace = typeof(SyntaxTreeHelpers).Namespace;
    }
}