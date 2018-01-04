//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;
using System.Linq;
using Antmicro.Renode.Logging;

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
            VisitSyntaxTreeInner<TValue, object>(root, visitorAction, null);
        }

        public static void VisitSyntaxTree<TValue, TFilter>(object root, Action<TValue> visitorAction, Func<TFilter, bool> filter) where TValue : class where TFilter : class
        {
            VisitSyntaxTreeInner(root, visitorAction, filter);
        }

        private static void VisitSyntaxTreeInner<TValue, TFilter>(object objectToVisit, Action<TValue> visitorAction, Func<TFilter, bool> filter) where TValue : class where TFilter : class
        {
            var objectAsValue = objectToVisit as TValue;
            if(objectAsValue != null)
            {
                visitorAction(objectAsValue);
            }

            var objectAsVisitable = objectToVisit as IVisitable;
            if(objectAsVisitable != null)
            {
                foreach(var element in objectAsVisitable.Visit())
                {
                    if(element != null && ApplyFilter(element, filter))
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
                            if(ApplyFilter(element, filter))
                            {
                                VisitSyntaxTreeInner(element, visitorAction, filter);
                            }
                        }
                    }
                    else if(typeOfValue.Namespace.StartsWith(OurNamespace, StringComparison.InvariantCulture))
                    {
                        if(ApplyFilter(propertyValue, filter))
                        {
                            VisitSyntaxTreeInner(propertyValue, visitorAction, filter);
                        }
                    }
                }
            }
        }

        private static bool ApplyFilter<T>(object obj, Func<T, bool> filter) where T : class
        {
            var objAsT = obj as T;
            if(filter == null || objAsT == null)
            {
                return true;
            }
            return filter(objAsT);
        }

        private static readonly string OurNamespace = typeof(SyntaxTreeHelpers).Namespace;
    }
}
